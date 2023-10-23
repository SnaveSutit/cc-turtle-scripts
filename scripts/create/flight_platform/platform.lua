-- wget http://localhost:3000/platform.lua startup.lua
-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/flight_platform/platform.lua

local function requireExternal(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename:match("[^%.]+"))
end

local modem = peripheral.find("modem")
local protocol = "snavesutit:flight_platform_controller"
local net = requireExternal(
-- "http://localhost:3000/networking.lua"
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/networking.lua"
)

local state = {
	controllerID = nil,
	position = { x = 0, z = 0 },
	targetPosition = { x = 0, z = 0 }
}

local function saveState()
	local file = fs.open(".platform_state", "w")
	file.write(textutils.serialize(state))
	file.close()
end

local function loadState()
	if not fs.exists(".platform_state") then return end
	local file = fs.open(".platform_state", "r")
	state = textutils.unserialize(file.readAll())
	file.close()
end

local function lookForControllers()
	while state.controllerID == nil do
		print("Looking for controllers...")
		repeat
			state.controllerID = rednet.lookup(protocol)
			sleep(1)
		until state.controllerID ~= nil
		print("Found controller: " .. state.controllerID)
		print("Attempting to link...")

		local success = net.requestFrom(state.controllerID, "snavesutit:link_controller", {
			isPlatform = true
		})

		if not success then
			print("Failed to link to controller.")
			state.controllerID = nil
			sleep(1)
		else
			print("Linked!")
			saveState()
		end
	end
end

local function reconnectController()
	local tries = 1
	print("Attempting to reconnect controller: " .. state.controllerID)
	local success, connected
	success = net.requestFrom(state.controllerID, "snavesutit:reconnect", {
		isPlatform = true
	}, function(_connected)
		connected = _connected
	end)
	if not (success or connected) then
		print("Failed to reconnect to controller.")
		sleep(1)
		tries = tries + 1
	else
		print("Reconnected!")
		return
	end
	print("Failed to reconnect to controller. Disconnecting...")
	state.controllerID = nil
	saveState()
end

local directionMap = {
	north = "front",
	east = "right",
	south = "back",
	west = "left"
}

local function triggerMovement(direction)
	local side = directionMap[direction]
	if side == "front" then  -- North
		state.position.z = state.position.z - 1
	elseif side == "right" then -- East
		state.position.x = state.position.x + 1
	elseif side == "back" then -- South
		state.position.z = state.position.z + 1
	elseif side == "left" then -- West
		state.position.x = state.position.x - 1
	end
	saveState()

	redstone.setOutput(side, true)
	sleep(0.05)
	redstone.setOutput(side, false)
	sleep(0.05)
end

local function main()
	net.init(modem, protocol)
	loadState()
	saveState()

	sleep(0.5)

	if state.controllerID ~= nil then
		state.targetPosition = { x = state.position.x, z = state.position.z }
		saveState()
		reconnectController()
	end
	if state.controllerID == nil then
		lookForControllers()
	end
	saveState()

	local distanceX = state.targetPosition.x - state.position.x
	local distanceZ = state.targetPosition.z - state.position.z

	shell.run("clear")
	print("Current position: " .. state.position.x .. ", " .. state.position.z)
	print("Target position: " .. state.targetPosition.x .. ", " .. state.targetPosition.z)
	print("Distance: " .. distanceX .. ", " .. distanceZ)

	if (distanceX ~= 0 or distanceZ ~= 0) then
		if distanceZ < 0 then
			triggerMovement("north")
		elseif distanceX > 0 then
			triggerMovement("east")
		elseif distanceZ > 0 then
			triggerMovement("south")
		elseif distanceX < 0 then
			triggerMovement("west")
		else
			error("Invalid target position")
		end
		return
	end

	local exit = false
	while (state.controllerID ~= nil and not exit) do
		parallel.waitForAny(
			function()
				net.heartbeatSender(state.controllerID)
				print("Lost connection to controller.")
				state.controllerID = nil
				saveState()
				exit = true
			end,
			function()
				-- TODO: Implement controller's side of re-connection
				net.listenForRequestFrom(state.controllerID, "snavesutit:reconnect", function(data, otherID)
					if data.isPlatform and state.controllerID == otherID then
						print("Controller Reconnected!")
					end
				end)
			end,
			function()
				-- TODO: Implement controller's side of re-connection
				net.listenForRequestFrom(state.controllerID, "snavesutit:disconnect", function(data, otherID)
					if data.isController and state.controllerID == otherID then
						print("Controller Disconnected: " .. data.reason)
						state.controllerID = nil
						exit = true
					end
				end)
			end,
			function()
				net.listenForRequestFrom(state.controllerID, "snavesutit:setzero", function(data)
					state.position = { x = data.zeroPosition.x, z = data.zeroPosition.z }
					state.targetPosition = { x = data.zeroPosition.x, z = data.zeroPosition.z }
				end)
				print("Zero set.")
			end,
			function()
				net.listenForRequestFrom(state.controllerID, "snavesutit:settargetpos", function(data)
					state.targetPosition = { x = data.targetPosition.x, z = data.targetPosition.z }
				end)
				print("Target position set to " .. state.targetPosition.x .. ", " .. state.targetPosition.z)
				exit = true
			end,
			function()
				net.listenForRequestFrom(state.controllerID, "snavesutit:setpos", function(data)
					state.position = { x = data.position.x, z = data.position.z }
				end)
				print("Target position set to " .. state.targetPosition.x .. ", " .. state.targetPosition.z)
				exit = true
			end,
			function()
				while true do
					net.listenForRequestFrom(state.controllerID, "snavesutit:getpos", function()
						print("Position requested.")
						return { position = state.position, targetPosition = state.targetPosition }
					end)
					print("Position sent.")
				end
			end
		)
		sleep(0.1)
	end

	saveState()
	os.reboot()
end

main()

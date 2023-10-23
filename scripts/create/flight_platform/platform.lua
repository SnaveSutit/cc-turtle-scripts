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
local state = requireExternal(
-- "http://localhost:3000/state.lua"
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/state_manager.lua"
)

local defaultState = {
	controllerID = nil,
	["targetPosition.x"] = 0,
	["targetPosition.z"] = 0,
	["position.x"] = 0,
	["position.z"] = 0
}

local function lookForControllers()
	local foundID
	while state.get("controllerID") == nil do
		print("Looking for controllers...")
		repeat
			foundID = rednet.lookup(protocol)
			sleep(1)
		until foundID ~= nil
		print("Found controller: " .. foundID)
		print("Attempting to link...")

		local success = net.requestFrom(state.get("controllerID"), "snavesutit:link_controller", {
			isPlatform = true
		})

		if not success then
			print("Failed to link to controller.")
			state.set("controllerID", nil)
			sleep(1)
		else
			state.set("controllerID", rednet.lookup(protocol))
			print("Linked!")
		end
	end
end

local function reconnectController()
	local tries = 1
	print("Attempting to reconnect controller: " .. state.get("controllerID") .. "...")
	local success, connected
	success = net.requestFrom(state.get("controllerID"), "snavesutit:reconnect", {
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
	state.set("controllerID", nil)
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
		state.set("position.z", state.get("position.z") - 1)
	elseif side == "right" then -- East
		state.set("position.x", state.get("position.x") + 1)
	elseif side == "back" then -- South
		state.set("position.z", state.get("position.z") + 1)
	elseif side == "left" then -- West
		state.set("position.x", state.get("position.x") - 1)
	end

	redstone.setOutput(side, true)
	sleep(0.05)
	redstone.setOutput(side, false)
	sleep(0.05)
end

local function main()
	net.init(modem, protocol)
	state.load(".platform_state", defaultState)

	sleep(0.5)

	if state.get("controllerID") ~= nil then
		state.set("targetPosition.x", state.get("position.x"))
		state.set("targetPosition.z", state.get("position.z"))
		reconnectController()
	end
	if state.get("controllerID") == nil then
		lookForControllers()
	end

	local distanceX = state.get("targetPosition.x") - state.get("position.x")
	local distanceZ = state.get("targetPosition.z") - state.get("position.z")

	shell.run("clear")
	print("Current position: " .. state.get("position.x") .. ", " .. state.get("position.z"))
	print("Target position: " .. state.get("targetPosition.x") .. ", " .. state.get("targetPosition.z"))
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
	while (state.get("controllerID") ~= nil and not exit) do
		parallel.waitForAny(
			function()
				net.heartbeatSender(state.get("controllerID"))
				print("Lost connection to controller.")
				state.set("controllerID", nil)
				exit = true
			end,
			function()
				-- TODO: Implement controller's side of re-connection
				net.listenForRequestFrom(state.get("controllerID"), "snavesutit:reconnect", function(data, otherID)
					if data.isPlatform and state.get("controllerID") == otherID then
						print("Controller Reconnected!")
					end
				end)
			end,
			function()
				-- TODO: Implement controller's side of re-connection
				net.listenForRequestFrom(state.get("controllerID"), "snavesutit:disconnect", function(data, otherID)
					if data.isController and state.get("controllerID") == otherID then
						print("Controller Disconnected: " .. data.reason)
						state.set("controllerID", nil)
						exit = true
					end
				end)
			end,
			function()
				net.listenForRequestFrom(state.get("controllerID"), "snavesutit:setzero", function(data)
					state.set("position.x", data.zeroPosition.x)
					state.set("position.z", data.zeroPosition.z)
					state.set("targetPosition.x", data.zeroPosition.x)
					state.set("targetPosition.z", data.zeroPosition.z)
				end)
				print("Zero set.")
			end,
			function()
				net.listenForRequestFrom(state.get("controllerID"), "snavesutit:settargetpos", function(data)
					state.set("targetPosition.x", data.targetPosition.x)
					state.set("targetPosition.z", data.targetPosition.z)
				end)
				print("Target position set to " .. state.get("targetPosition.x") .. ", " .. state.get("targetPosition.z"))
				exit = true
			end,
			function()
				net.listenForRequestFrom(state.get("controllerID"), "snavesutit:setpos", function(data)
					state.set("position.x", data.position.x)
					state.set("position.z", data.position.z)
				end)
				print("Position set to " .. state.get("position.x") .. ", " .. state.get("position.z"))
				exit = true
			end,
			function()
				while true do
					net.listenForRequestFrom(state.get("controllerID"), "snavesutit:getpos", function()
						print("Position requested.")
						return {
							position = {
								x = state.get("position.x"),
								z = state.get("position.z")
							},
							targetPosition = {
								x = state.get("targetPosition.x"),
								z = state.get("targetPosition.z")
							}
						}
					end)
					print("Position sent.")
				end
			end
		)
		sleep(0.1)
	end

	os.reboot()
end

main()

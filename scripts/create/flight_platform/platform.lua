-- wget http://localhost:3000/platform.lua startup.lua

local function requireExternal(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename:match("[^%.]+"))
end

local modem = peripheral.find("modem")
local controllerID
local protocal = "snavesutit:flight_platform_controller"
local net = requireExternal(
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/networking.lua")

local state = {
	moving = false,
	direction = nil,
	distance = nil,
	connectionID = nil,
	position = { x = 0, z = 0 },
	targetPosition = { x = 0, z = 0 }
}

local function saveState()
	local file = fs.open("state", "w")
	file.write(textutils.serialize(state))
	file.close()
end

local function loadState()
	if not fs.exists("state") then return end
	local file = fs.open("state", "r")
	state = textutils.unserialize(file.readAll())
	file.close()
end

local function lookForControllers()
	while controllerID == nil do
		print("Looking for controllers...")
		repeat
			controllerID = rednet.lookup(protocal)
			sleep(1)
		until controllerID ~= nil
		print("Found controller: " .. controllerID)
		print("Attempting to link...")

		local success = net.requestFrom(controllerID, "snavesutit:link_controller", {
			title = "snavesutit:link_controller",
			isPlatform = true
		})

		if not success then
			print("Failed to link to controller.")
			controllerID = nil
			sleep(1)
		else
			print("Linked!")
		end
	end
end

local function reconnectController()
	print("Reconnecting to controller: " .. state.connectionID)
	controllerID = state.connectionID
	rednet.send(controllerID, {
		title = "snavesutit:reconnect"
	}, protocal)
	print("Reconnected!")
end


local function triggerMovement(side, distance)
	state.moving = true
	state.direction = side
	state.distance = distance
	if side == "front" then  -- North
		state.position.z = state.position.z - 1
	elseif side == "back" then -- South
		state.position.z = state.position.z + 1
	elseif side == "right" then -- East
		state.position.x = state.position.x + 1
	elseif side == "left" then -- West
		state.position.x = state.position.x - 1
	end
	saveState()

	redstone.setOutput(side, true)
	sleep(0.05)
	redstone.setOutput(side, false)
	sleep(0.05)
end

local function parseCommand(command)
	if command.title == "disconnect" then
		state.connectionID = nil
		saveState()
		print("Disconnected from controller.")
		return true
	elseif command.title == "move" then
		if command.direction == "north" then
			state.targetPosition.z = state.targetPosition.z - command.distance
			triggerMovement("front", command.distance)
		elseif command.direction == "south" then
			state.targetPosition.z = state.targetPosition.z + command.distance
			triggerMovement("back", command.distance)
		elseif command.direction == "east" then
			state.targetPosition.x = state.targetPosition.x + command.distance
			triggerMovement("right", command.distance)
		elseif command.direction == "west" then
			state.targetPosition.x = state.targetPosition.x - command.distance
			triggerMovement("left", command.distance)
		end
	elseif command.title == "settarget" then
		state.targetPosition.x = command.x ~= nil and command.x or state.position.x
		state.targetPosition.z = command.z ~= nil and command.z or state.position.z
		saveState()
		rednet.send(controllerID, {
			title = "snavesutit:target_set",
			dx = state.targetPosition.x - state.position.x,
			dz = state.targetPosition.z - state.position.z
		}, protocal)
		os.reboot()
	elseif command.title == "setzero" then
		state.position = { x = 0, z = 0 }
		state.targetPosition = { x = 0, z = 0 }
		saveState()
		os.reboot()
	elseif command.title == "getpos" then
		rednet.send(controllerID, {
			title = "snavesutit:position",
			x = state.position.x,
			z = state.position.z
		}, protocal)
		os.reboot()
	end
end

local function test()
end

local function main()
	net.init(modem, protocal)
	loadState()
	saveState()

	sleep(0.1)

	shell.run("clear")
	print("Current position: " .. state.position.x .. ", " .. state.position.z)
	print("Target position: " .. state.targetPosition.x .. ", " .. state.targetPosition.z)
	print("Moving: " .. tostring(state.moving))
	print("Connected: " .. tostring(not not state.connectionID))

	if state.moving then
		print("Resuming movement: " .. state.direction .. " " .. state.distance .. " chunks...")
		local xDistance = state.targetPosition.x - state.position.x
		local zDistance = state.targetPosition.z - state.position.z
		print("Distance left to traverse: ", zDistance, xDistance)

		if state.connectionID ~= nil then
			rednet.send(state.connectionID, {
				title = "snavesutit:target_update",
				dx = xDistance,
				dz = zDistance
			}, protocal)
		end

		state.distance = state.distance - 1
		if state.distance <= 0 then
			print("Done moving " .. state.direction .. ".")
			state.moving = false
			saveState()
		else
			triggerMovement(state.direction, state.distance)
			return
		end
	end

	if not state.moving
		and (state.position.x ~= state.targetPosition.x
			or state.position.z ~= state.targetPosition.z)
	then
		print("Moving to target position...")
		local xDistance = state.targetPosition.x - state.position.x
		local zDistance = state.targetPosition.z - state.position.z
		print("Distance left to traverse: ", zDistance, xDistance)

		if xDistance > 0 then
			triggerMovement("right", math.abs(xDistance))
		elseif xDistance < 0 then
			triggerMovement("left", math.abs(xDistance))
		elseif zDistance < 0 then
			triggerMovement("front", math.abs(zDistance))
		elseif zDistance > 0 then
			triggerMovement("back", math.abs(zDistance))
		end

		sleep(0.25)
		if state.connectionID ~= nil then
			rednet.send(state.connectionID, {
				title = "snavesutit:target_update",
				reachedTarget = true
			}, protocal)
		end
		return
	end

	if state.connectionID == nil then
		lookForControllers()
	else
		reconnectController()
	end
	state.connectionID = controllerID
	saveState()

	while true do
		local senderID, message = rednet.receive(protocal)
		if senderID == controllerID then
			if parseCommand(message) then
				break
			end
		end
	end
end

-- main()
test()

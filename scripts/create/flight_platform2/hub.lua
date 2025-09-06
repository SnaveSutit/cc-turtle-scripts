-- hub
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

local rednetModem = peripheral.wrap("top")
local modem = peripheral.wrap("bottom")
local wingTurtles = {
	north = {},
	south = {},
	east = {},
	west = {},
}
local wingGearshifts = {
	north = {},
	south = {},
	east = {},
	west = {},
}
local wingTravelDistance = 16

modem.open(1)

local function timeout(seconds)
	local id = os.startTimer(seconds)
	local event
	repeat
		event = { os.pullEvent() }
	until event[1] == "timer" and event[2] == id
end

table.contains = function(table, value)
	for _, v in ipairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

local function getCreateSequencedGearshiftPeripherals()
	local things = peripheral.getNames()
	local filtered = {}
	for _, peripheralName in ipairs(things) do
		if peripheralName:match("^Create_SequencedGearshift_") then
			table.insert(filtered, {
				name = peripheralName,
				peripheral = peripheral.wrap(peripheralName),
				forwardDirection = 1
			})
		end
	end
	return filtered
end

local function collectTurtlePeripherals()
	local things = peripheral.getNames()
	local filtered = {}
	for _, peripheralName in ipairs(things) do
		if peripheralName:match("^turtle") then
			local peripheral = peripheral.wrap(peripheralName)
			local name = peripheral.getLabel()
			if wingTurtles[name] then
				wingTurtles[name] = peripheral
			end
		end
	end
	if not wingTurtles.north then
		error("No north wing turtle found.")
	elseif not wingTurtles.south then
		error("No south wing turtle found.")
	elseif not wingTurtles.east then
		error("No east wing turtle found.")
	elseif not wingTurtles.west then
		error("No west wing turtle found.")
	end
	return filtered
end

local function moveGearshift(gearshift, distance, waitForMovement)
	if waitForMovement == nil then
		waitForMovement = true
	end
	sleep(0.05)
	local direction = gearshift.forwardDirection
	if distance < 0 then
		direction = direction * -1
	end
	gearshift.peripheral.move(distance, direction)
	if waitForMovement then
		while gearshift.peripheral.isRunning() do
			sleep(0.05)
		end
		sleep(0.05)
	end
end

local function waitForGearshiftToStop(gearshift)
	while gearshift.peripheral.isRunning() do
		sleep(0.05)
	end
	sleep(0.05)
end

local function waitForModemMessage(condition)
	local channel, message, distance
	repeat
		_, _, channel, _, message, distance = os.pullEvent("modem_message")
	until condition({
			channel = channel,
			message = message,
			distance = distance,
		})
end

local function waitForTurtleOnlineMessage(turtle)
	local turtleOnline = false
	local turtleName = turtle.getLabel()
	local distance
	waitForModemMessage(function(data)
		if data.channel == 1 and data.message == turtleName .. ":online" then
			turtleOnline = true
			distance = data.distance
			return true
		end
	end)
	if not turtleOnline then
		error("Failed to wait for turtle: " .. turtleName .. " to come online.")
	end
	return distance
end

local function sendCommandToWingTurtle(turtle, command)
	local turtleName = turtle.getLabel()
	modem.transmit(1, 1, turtleName .. ":" .. command)
	local turtleSuccess = false
	parallel.waitForAny(
		function()
			waitForModemMessage(function(data)
				if data.channel == 1 and data.message == turtleName .. ':ack' then
					turtleSuccess = true
					return true
				end
			end)
		end,
		function()
			timeout(10)
		end
	)
	if not turtleSuccess then
		error("Failed to send command: " .. turtleName .. " did not respond.")
	end
end

local function calibrate()
	local gearshifts = getCreateSequencedGearshiftPeripherals()

	for turtleName, turtle in pairs(wingTurtles) do
		if turtle.isOn() then
			turtle.reboot()
		else
			turtle.turnOn()
		end
		parallel.waitForAny(
			function()
				waitForTurtleOnlineMessage(turtle)
				print("Turtle: " .. turtleName .. " is online.")
			end,
			function()
				timeout(5)
				error("Failed to wait for turtle: " .. turtleName .. " to come online.")
			end
		)
		sendCommandToWingTurtle(turtle, "reset")
	end

	-- Identify wing gearshifts
	for _, gearshift in ipairs(gearshifts) do
		local movedTurtle
		local direction = -1
		local distanceA, distanceB
		while not movedTurtle do
			direction = direction * -1
			for _, turtle in pairs(wingTurtles) do
				sendCommandToWingTurtle(turtle, "stick")
			end
			moveGearshift(gearshift, wingTravelDistance * direction, false)
			parallel.waitForAny(
				function()
					waitForModemMessage(function(data)
						if data.channel == 1 and data.message:match("online$") then
							local name = data.message:match("^(.*):")
							movedTurtle = wingTurtles[name]
							distanceA = data.distance
							return true
						end
					end)
				end,
				function()
					waitForGearshiftToStop(gearshift)
					sleep(0.25)
				end
			)
		end
		print("Moved turtle: " .. movedTurtle.getLabel() .. " distance A: " .. distanceA)
		wingGearshifts[movedTurtle.getLabel()] = gearshift

		moveGearshift(gearshift, -wingTravelDistance, false)
		parallel.waitForAny(
			function()
				distanceA = waitForTurtleOnlineMessage(movedTurtle)
			end,
			function()
				waitForGearshiftToStop(gearshift)
				sleep(0.25)
			end
		)

		moveGearshift(gearshift, wingTravelDistance, false)
		parallel.waitForAny(
			function()
				distanceB = waitForTurtleOnlineMessage(movedTurtle)
			end,
			function()
				waitForGearshiftToStop(gearshift)
				sleep(0.25)
				error("Failed to calibrate: " .. movedTurtle.getLabel() .. " did not come online.")
			end
		)
		if distanceA < distanceB then
			gearshift.forwardDirection = -1
			moveGearshift(gearshift, wingTravelDistance)
		end
		sleep(0.05)
		print("Calibrated " .. movedTurtle.getLabel() .. " wing gearshift.")
	end
	sleep(0.05)

	state.set("wingGearshifts", {
		north = {
			name = wingGearshifts.north.name,
			forwardDirection = wingGearshifts.north.forwardDirection
		},
		south = {
			name = wingGearshifts.south.name,
			forwardDirection = wingGearshifts.south.forwardDirection
		},
		east = {
			name = wingGearshifts.east.name,
			forwardDirection = wingGearshifts.east.forwardDirection
		},
		west = {
			name = wingGearshifts.west.name,
			forwardDirection = wingGearshifts.west.forwardDirection
		},
	})
end

local function moveWingThenWaitForStop(turtle, gearshift, direction)
	moveGearshift(gearshift, wingTravelDistance * direction, false)
	parallel.waitForAny(
		function()
			waitForTurtleOnlineMessage(turtle)
		end,
		function()
			waitForGearshiftToStop(gearshift)
			sleep(1)
			error("Failed to move wing " .. turtle.getLabel() .. ". Turtle did not come back online in time.")
		end
	)
	sleep(0.05)
end

local function stickAllWings()
	for _, turtle in pairs(wingTurtles) do
		sendCommandToWingTurtle(turtle, "stick")
	end
end

local function startMove(direction)
	stickAllWings()
	local turtle = wingTurtles[direction]
	state.set("justMovedTowards", direction)

	local pos = state.get("pos")
	if direction == 'north' then
		pos.z = pos.z - 1
	elseif direction == 'south' then
		pos.z = pos.z + 1
	elseif direction == 'east' then
		pos.x = pos.x + 1
	elseif direction == 'west' then
		pos.x = pos.x - 1
	end
	state.set("pos", {
		x = pos.x,
		z = pos.z,
	})

	sendCommandToWingTurtle(turtle, "push")
end

local function finishMove(direction)
	local turtle = wingTurtles[direction]
	local gearshift = wingGearshifts[direction]
	sleep(0.1)
	moveGearshift(gearshift, -wingTravelDistance)
	sendCommandToWingTurtle(turtle, "stick")
	moveWingThenWaitForStop(turtle, gearshift, 1)
	state.set("justMovedTowards", nil)
end


local defaultState = {
	needsCalibration = true,
	wingGearshifts = {
		north = {
			name = nil,
			forwardDirection = 1
		},
		south = {
			name = nil,
			forwardDirection = 1
		},
		east = {
			name = nil,
			forwardDirection = 1
		},
		west = {
			name = nil,
			forwardDirection = 1
		},
	},
	justMovedTowards = nil,
	pos = { x = 0, z = 0 },
	targetPos = { x = 0, z = 0 }
}

local function collectGearshiftPeripherals()
	local stateGearshifts = state.get("wingGearshifts")
	for direction, gearshift in pairs(stateGearshifts) do
		if not gearshift.name then
			return false
		end
		local p = peripheral.wrap(gearshift.name)
		if not p then
			return false
		end
		wingGearshifts[direction] = {
			name = gearshift.name,
			peripheral = p,
			forwardDirection = gearshift.forwardDirection
		}
	end
	return true
end

local function main()
	state.load(".state", defaultState)
	collectTurtlePeripherals()

	local success = collectGearshiftPeripherals()
	if not success or state.get("needsCalibration") then
		calibrate()
		state.set("needsCalibration", false)
		state.set("justMovedTowards", nil)
	end

	local justMovedTowards = state.get("justMovedTowards")
	if not (justMovedTowards == nil) then
		finishMove(justMovedTowards)
	end

	local invalidWingState = false
	for _, turtle in pairs(wingTurtles) do
		if not turtle.isOn() then
			turtle.turnOn()
		else
			turtle.reboot()
		end
		local distance = 0
		parallel.waitForAny(
			function()
				distance = waitForTurtleOnlineMessage(turtle)
			end,
			function()
				timeout(5)
				error("Failed to wait for turtle: " .. turtle.getLabel() .. " to come online.")
			end
		)
		if distance > 10 then
			print("Turtle: " .. turtle.getLabel() .. " is too far away from the gearshift. Requesting calibration.")
			state.set("needsCalibration", true)
			sendCommandToWingTurtle(turtle, "reset")
			invalidWingState = true
			print()
		end
	end
	if invalidWingState then
		error("Invalid wing state detected. Requesting calibration.")
	end

	local pos = state.get("pos")
	local targetPos = state.get("targetPos")
	if pos.x ~= targetPos.x or pos.z ~= targetPos.z then
		print("Current position: " .. pos.x .. ", " .. pos.z)
		print("Moving to target position: " .. targetPos.x .. ", " .. targetPos.z)
		local dx = targetPos.x - pos.x
		local dz = targetPos.z - pos.z
		if math.abs(dx) > math.abs(dz) then
			if dx > 0 then
				startMove('east')
			else
				startMove('west')
			end
		else
			if dz > 0 then
				startMove('south')
			else
				startMove('north')
			end
		end
	end
end

main()

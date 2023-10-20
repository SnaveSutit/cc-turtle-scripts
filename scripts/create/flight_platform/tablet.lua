-- wget http://localhost:3000/tablet.lua controller.lua
local protocal = "snavesutit:flight_platform_controller"
local platformID

local function awaitReconnect()
	local message
	repeat
		_, message = rednet.receive(protocal)
	until message.title == "snavesutit:reconnect"
end

local function awaitMessage(title)
	local message
	repeat
		_, message = rednet.receive(protocal)
	until message.title == title
	return message
end

local function main()
	rednet.open("back")
	rednet.host(protocal, "snavesutit:handheld_flight_platform_controller")

	print("Looking for platform...")

	local senderID, message
	repeat
		senderID, message = rednet.receive(protocal)
	until message.title == "snavesutit:link_controller"
	platformID = senderID

	print("Found platform: " .. platformID)
	print("Current position: " .. message.position.x .. ", " .. message.position.z)
	print("Target position: " .. message.targetPosition.x .. ", " .. message.targetPosition.z)

	rednet.unhost(protocal)

	while true do
		io.stdout:write("Enter platform command\n: ")
		local command = io.stdin:read()
		if command == "exit" then
			rednet.send(platformID, {
				title = "disconnect"
			}, protocal)
			print("Disconnected from platform.")
			break
		elseif command:sub(1, 4) == "move" then
			command = command:sub(6)
			local direction = command:gsub("[%d%s]", "")
			local distance = tonumber(command:match('%d+'))
			if distance == nil then
				distance = 1
			end
			rednet.send(platformID, {
				title = "move",
				direction = direction,
				distance = distance
			}, protocal)
			print("Moving " .. direction .. " " .. distance .. " chunks...")
			awaitReconnect()
			print("Done moving " .. direction .. ".")
		elseif command:sub(1, 9) == "settarget" then
			command = command:sub(11)
			local x, z = command:match('(-?%d+)%s(-?%d+)')
			if x == nil or z == nil then
				print("Invalid target position.")
			else
				rednet.send(platformID, {
					title = "settarget",
					x = tonumber(x),
					z = tonumber(z)
				}, protocal)
				local data = awaitMessage("snavesutit:target_set")
				print("Set target position to " .. x .. ", " .. z .. ".")
				print("Distance to target: " .. data.dx .. ", " .. data.dz .. ".")
				print("Moving to target position...")

				repeat
					data = awaitMessage("snavesutit:target_update")
					if not data.reachedTarget then
						print("Moving to target position...")
						print("Current Target: " .. x .. ", " .. z .. ".")
						print("Distance to Target: " .. data.dx .. ", " .. data.dz .. ".")
					end
				until data.reachedTarget == true
				awaitReconnect()
				print("Platform at target position.")
			end
		elseif command == "setzero" then
			rednet.send(platformID, {
				title = "setzero"
			}, protocal)
			print("Zeroing platform position...")
			awaitReconnect()
			print("Zeroed platform position.")
		elseif command == "getpos" then
			rednet.send(platformID, {
				title = "getpos"
			}, protocal)
			local data = awaitMessage("snavesutit:position")
			print("Current position: " .. data.x .. ", " .. data.z)
			awaitReconnect()
		end
	end
end

main()

-- wget http://localhost:3000/tablet.lua controller.lua

local function requireExternal(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename)
end

local modem = peripheral.find("modem")
local protocol = "snavesutit:flight_platform_controller"
local hostname = "snavesutit:handheld_flight_platform_controller"
local platformID
local net = requireExternal(
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/networking.lua")

local function main()
	net.init(modem, protocol)
	net.host(hostname)
	print("Looking for platform...")

	local success
	while platformID == nil do
		success = net.listenForRequest("snavesutit:link_controller", function(data, otherID)
			if data.isPlatform then
				platformID = otherID
				print("Found platform: " .. platformID)
			end
		end)
		if not success then
			print("Failed to link to platform.")
			sleep(1)
		end
	end
	print("Linked!")
	net.unhost(hostname)

	-- print("Current position: " .. message.position.x .. ", " .. message.position.z)
	-- print("Target position: " .. message.targetPosition.x .. ", " .. message.targetPosition.z)

	while true do
		io.stdout:write("Enter platform command\n: ")
		local command = io.stdin:read()
		if command == "exit" then
			rednet.send(platformID, {
				title = "disconnect"
			}, protocol)
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
			}, protocol)
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
				}, protocol)
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
			}, protocol)
			print("Zeroing platform position...")
			awaitReconnect()
			print("Zeroed platform position.")
		elseif command == "getpos" then
			rednet.send(platformID, {
				title = "getpos"
			}, protocol)
			local data = awaitMessage("snavesutit:position")
			print("Current position: " .. data.x .. ", " .. data.z)
			awaitReconnect()
		end
	end
end

main()

-- wget http://localhost:3000/tablet.lua controller.lua

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
local hostname = "snavesutit:handheld_flight_platform_controller"
local platformID
local exit = false
local net = requireExternal(
-- "http://localhost:3000/networking.lua"
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/networking.lua"
)

local function parseCommand(command)
	if command == "exit" then
		net.requestFrom(platformID, "snavesutit:disconnect", {
			isController = true,
			reason = "user_exit"
		})
		platformID = nil
		exit = true
		print("Disconnected from platform.")
	elseif command:match("^goto") then
		local x, z = command:match("^goto%s+(%-?%d+)%s+(%-?%d+)$")
		x, z = tonumber(x), tonumber(z)
		if x == nil or z == nil then
			print("Invalid Coordinates.")
		else
			local success = net.requestFrom(platformID, "snavesutit:settargetpos", {
				targetPosition = { x = x, z = z }
			})
			if not success then
				print("Failed to set target position. Platform may be disconnected.")
			else
				print("Set target position to " .. x .. ", " .. z)
			end
		end
	elseif command == "setzero" then
		local success = net.requestFrom(platformID, "snavesutit:setzero", {
			zeroPosition = { x = 0, z = 0 }
		})
		if not success then
			print("Failed to set zero position. Platform may be disconnected.")
		else
			print("Set zero position to current location.")
		end
	elseif command == "getpos" then
		local data
		local success = net.requestFrom(platformID, "snavesutit:getpos", {}, function(_data)
			data = _data
		end)
		if not success then
			print("Failed to get position. Platform may be disconnected.")
		else
			print("Current Position: " .. data.position.x .. ", " .. data.position.z)
			print("Target Position: " .. data.targetPosition.x .. ", " .. data.targetPosition.z)
		end
	elseif command:match("^setpos") then
		local x, z = command:match("^setpos%s+(%-?%d+)%s+(%-?%d+)$")
		x, z = tonumber(x), tonumber(z)
		if x == nil or z == nil then
			print("Invalid Coordinates.")
		else
			local success = net.requestFrom(platformID, "snavesutit:setpos", {
				position = { x = x, z = z }
			})
			if not success then
				print("Failed to set position. Platform may be disconnected.")
			else
				print("Set position to " .. x .. ", " .. z)
			end
		end
	else
		print("Invalid Command.")
	end
end

local function connectToPlatform()
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
end

local function main()
	net.init(modem, protocol)
	net.host(hostname)
	print("Looking for platform...")

	connectToPlatform()

	while platformID ~= nil and not exit do
		parallel.waitForAny(
			function()
				net.heartbeatReciever(platformID)
				print("Lost Connection to Platform.")
				platformID = nil
			end,
			function()
				while true do
					net.listenForRequestFrom(platformID, "snavesutit:reconnect", function(data, otherID)
						if data.isPlatform and platformID == otherID then
							return true
						end
						return false
					end)
				end
			end,
			function()
				while not exit do
					io.stdout:write("Enter platform command\n: ")
					local command = io.stdin:read()
					parseCommand(command)
				end
			end
		)
		sleep(0.1)
	end
end

main()

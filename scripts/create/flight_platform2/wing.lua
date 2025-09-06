-- wing turtle
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
local defaultState = {
	rotationNormal = 1
}
state.load(".state", defaultState)

local modem = peripheral.find("modem")
local gearshift = peripheral.wrap("right") or error("No gearshift found")
local speaker = peripheral.find("speaker")
local label = os.getComputerLabel()
local wingTravelDistance = 16


modem.open(1)
modem.transmit(1, 1, label .. ":online")

speaker.playNote("bit")
print("Started wing turtle " .. label)

local function isExtended()
	local block = ({ turtle.inspect() })[2]
	if block.name == 'create:piston_extension_pole' then
		return true
	end
	return false
end

local function setSticker(stuck)
	local block = ({ turtle.inspect() })[2]
	if block.state and block.state.extended == stuck then
		return
	end
	redstone.setOutput("front", true)
	sleep(0.05)
	redstone.setOutput("front", false)
	sleep(0.05)
end

local function moveGearshift(gearshift, distance, waitForMovement)
	if waitForMovement == nil then
		waitForMovement = true
	end
	sleep(0.05)
	local direction = 1
	if distance < 0 then
		direction = direction * -1
	end
	gearshift.move(distance, direction)
	if waitForMovement then
		while gearshift.isRunning() do
			sleep(0.05)
		end
		sleep(0.05)
	end
end

local function ackgnowledgeCommand()
	modem.transmit(1, 1, label .. ":ack")
end

while true do
	local message
	repeat
		message = ({ os.pullEvent("modem_message") })[5]
	until message:match("^" .. label .. ":")

	local command = message:match("^" .. label .. ":(.*)$")

	print("Received command: " .. command)

	if command == "unstick" then
		setSticker(false)
	elseif command == "stick" then
		setSticker(true)
	elseif command == "reset" then
		setSticker(true)
		moveGearshift(gearshift, wingTravelDistance * state.get("rotationNormal"))
		if isExtended() then
			state.set("rotationNormal", state.get("rotationNormal") * -1)
			moveGearshift(gearshift, wingTravelDistance * state.get("rotationNormal"))
		end
	elseif command == "push" then
		setSticker(false)
		moveGearshift(gearshift, -wingTravelDistance * state.get("rotationNormal"))
		moveGearshift(gearshift, wingTravelDistance * state.get("rotationNormal"))
	else
		error("Unknown command: " .. command)
	end

	ackgnowledgeCommand()
end

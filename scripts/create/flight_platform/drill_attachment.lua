local function requireExternal(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename:match("[^%.]+"))
end
local net = requireExternal(
-- "http://localhost:3000/networking.lua"
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/networking.lua"
)
local state = requireExternal(
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/state_manager.lua"
)
local modem = peripheral.find("modem")
local protocol = "snavesutit:drill_controller"
local hostname = "snavesutit:drill_attachment"
local controllerID

local defaultState = {}

local function connectToDrillController()
end

local function reconnectToDrillController()
end

local function main()
	state.load(defaultState)

	if state.get("controllerID") ~= nil then
		reconnectToDrillController()
	end
	if state.get("controllerID") == nil then
		connectToDrillController()
	end
end

main()

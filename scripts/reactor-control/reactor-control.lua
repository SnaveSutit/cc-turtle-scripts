local reactorController = peripheral.find("fissionReactorLogicAdapter")
while not reactorController do
	print("Waiting for fission reactor logic adapter...")
	os.sleep(1)
	reactorController = peripheral.find("fissionReactorLogicAdapter")
end

local gui = require("gui")

local powerStorageController = peripheral.find("inductionPort")
local chatBox = peripheral.find("chat_box")

local screenX, screenY = term.getSize()
-- true = reactor is active, false = reactor is inactive
local targetReactorStatus = true

gui.addButton {
	label = "START REACTOR",
	x = 4,
	y = screenY - 3,
	color = colors.green,
	onClick = function()
		targetReactorStatus = true
		if not reactorController.getStatus() then
			reactorController.activate()
		end
		redstone.setOutput("top", true)
		os.sleep(1.4)
		redstone.setOutput("top", false)
	end
}

gui.addButton {
	label = "SCRAM REACTOR",
	x = screenX - 15,
	y = screenY - 3,
	color = colors.red,
	onClick = function()
		targetReactorStatus = false
		if reactorController.getStatus() then
			reactorController.scram()
		end
		redstone.setOutput("top", true)
		os.sleep(1.4)
		redstone.setOutput("top", false)
	end
}

local function monitorThread()
	while true do
		local allGood = true

		local temperature = reactorController.getTemperature()
		local isActive = reactorController.getStatus()

		if temperature >= 800 then
			pcall(reactorController.scram)
			redstone.setOutput("top", true)
			gui.setStatusMessage("OVERHEATED!")
			targetReactorStatus = false
			allGood = false
		elseif temperature >= 600 then
			redstone.setOutput("top", true)
			gui.setStatusMessage("TEMPERATURE HIGH")
			allGood = false
		end

		-- If the target reactor status is ACTIVE, automatically adjust it's status based on fuel, waste, and energy levels.
		if targetReactorStatus then
			local waste = reactorController.getWasteFilledPercentage()
			local fuel = reactorController.getFuelFilledPercentage()
			local energy = powerStorageController.getEnergyFilledPercentage()

			if isActive then
				if waste >= 0.9 then
					gui.setStatusMessage("WASTE TANK FULL")
					allGood = false
				elseif energy >= 0.9 then
					allGood = false
					gui.setStatusMessage("ENERGY STORAGE FULL")
				elseif fuel <= 0.1 then
					allGood = false
					gui.setStatusMessage("FUEL LEVEL LOW")
				end
			else
				if waste >= 0.25 then
					gui.setStatusMessage("WASTE TANK FULL")
					allGood = false
				elseif energy >= 0.25 then
					allGood = false
					gui.setStatusMessage("ENERGY STORAGE FULL")
				elseif fuel <= 0.75 then
					allGood = false
					gui.setStatusMessage("FUEL LEVEL LOW")
				end
			end


			if allGood and not isActive then
				pcall(reactorController.activate)
				gui.setStatusMessage(nil)
			end
		end

		if not allGood then
			pcall(reactorController.scram)
		end

		os.sleep(0.1)
	end
end

local function buttonThread()
	while true do
		gui.processButtons()
	end
end

local function guiThread()
	while true do
		gui.drawReactorStatus(reactorController, powerStorageController)
		os.sleep(1)
	end
end

local function main()
	redstone.setOutput("top", false)

	parallel.waitForAny(
		buttonThread,
		guiThread,
		monitorThread
	)
end

main()

local gui = require("gui")

local reactorController = peripheral.find("fissionReactorLogicAdapter")
local powerStorageController = peripheral.find("inductionPort")
local chatBox = peripheral.find("chat_box")

local screenX, screenY = term.getSize()
-- true = reactor is active, false = reactor is inactive
local targetReactorStatus = true

function sendScramMessage(message)
	chatBox.sendFormattedMessage(textutils.serialiseJSON {
		text = message,
		color = "red"
	})
	term.clear()
	term.setCursorPos(1, 1)
	term.setTextColor(colors.red)
	term.write(message)
end

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

function monitorThread()
	while true do
		local temperature = reactorController.getTemperature()
		local isActive = reactorController.getStatus()

		if temperature >= 800 then
			pcall(reactorController.scram)
			redstone.setOutput("top", true)
			sendScramMessage("Reactor SCRAM initiated due to critical temperature!")
			return
		elseif temperature >= 600 then
			redstone.setOutput("top", true)
		end

		local waste = reactorController.getWasteFilledPercentage()
		if waste >= 0.9 then
			pcall(reactorController.scram)
			sendScramMessage("Reactor waste level critical! Please empty the waste tank.")
			return
		end

		local fuel = reactorController.getFuelFilledPercentage()
		if fuel <= 0.1 then
			pcall(reactorController.scram)
			sendScramMessage("Reactor fuel level critical! Please refuel the reactor.")
			return
		end

		-- If the target reactor status is ACTIVE, automatically toggle based on energy storage levels
		if targetReactorStatus then
			local energy = powerStorageController.getEnergyFilledPercentage()
			if isActive and energy >= 0.9 then
				pcall(reactorController.scram)
			elseif not isActive and energy <= 0.5 then
				pcall(reactorController.activate)
			end
		end

		os.sleep(0.1)
	end
end

function buttonThread()
	while true do
		gui.processButtons()
	end
end

function guiThread()
	while true do
		gui.drawReactorStatus(reactorController, powerStorageController)
		os.sleep(1)
	end
end

function main()
	redstone.setOutput("top", false)

	parallel.waitForAny(
		buttonThread,
		guiThread,
		monitorThread
	)
end

main()

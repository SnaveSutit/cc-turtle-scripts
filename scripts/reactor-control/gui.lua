function reformatInt(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

function padStart(text, totalLength, paddingChar)
	paddingChar = paddingChar or " "
	local textLength = #text
	if textLength >= totalLength then
		return text
	end
	local paddingNeeded = totalLength - textLength
	return string.rep(paddingChar, paddingNeeded) .. text
end

function nextLine()
	term.setCursorPos(1, ({ term.getCursorPos() })[2] + 1)
end

local gui = {}

function gui.setColor(color)
	term.setTextColor(color or colors.white)
end

function gui.setBGColor(color)
	term.setBackgroundColor(color or colors.black)
end

function gui.writeCenteredText(y, text, color, bgColor, paddingChar, paddingColor, paddingBGColor)
	local screenSizeX, _ = term.getSize()
	local textLength = #text
	local startX = math.floor((screenSizeX - textLength) / 2) + 1

	term.setCursorPos(1, y)
	if paddingChar then
		term.clearLine()
		gui.setColor(paddingColor)
		gui.setBGColor(paddingBGColor)
		term.write(string.rep(paddingChar, startX))
		term.setCursorPos(1, y)
	end

	gui.setColor(color)
	gui.setBGColor(bgColor)
	term.setCursorPos(startX, y)
	term.write(text)

	if paddingChar then
		gui.setColor(paddingColor)
		gui.setBGColor(paddingBGColor)
		term.setCursorPos(startX + textLength, y)
		term.write(string.rep(paddingChar, screenSizeX - (startX + textLength) + 1))
	end

	gui.setColor()
	gui.setBGColor()

	term.setCursorPos(1, y + 1)
end

function gui.writeProgressBar(progress, lowIsGood)
	local x, y = term.getCursorPos()

	local percentage = math.floor(progress * 100) .. "%"
	percentage = padStart(percentage, 4, " ")

	local screenX = term.getSize()
	local prefix = "["
	local suffix = "]     "
	local totalWidth = screenX - x - #prefix - #suffix
	local filledWidth = math.ceil(totalWidth * progress)
	local emptyWidth = math.ceil(totalWidth - filledWidth)

	local lowColor = lowIsGood and colors.green or colors.red
	local highColor = lowIsGood and colors.red or colors.green

	term.setTextColor(colors.lightGray)
	term.write(prefix)

	local progressColor = colors.yellow
	if progress <= 0.25 then
		progressColor = lowColor
	elseif progress >= 0.75 then
		progressColor = highColor
	end

	term.setTextColor(progressColor)
	term.write(string.rep("#", filledWidth))

	term.setTextColor(colors.white)
	term.write(string.rep(" ", emptyWidth))
	term.setTextColor(colors.lightGray)
	term.write("] ")

	term.setTextColor(progressColor)
	term.setCursorPos(screenX - #percentage, y)
	term.write(percentage)
	term.write("   ")

	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.setCursorPos(1, y + 1)
end

function gui.writeFormattedText(...)
	local x, y = term.getCursorPos()
	local textTable = { ... }
	for i, obj in ipairs(textTable) do
		if obj.centered == true then
			assert(obj.text, "Text entry missing 'text' field at index " .. i)
			gui.writeCenteredText(
				y,
				obj.text,
				obj.color,
				obj.bgColor,
				obj.paddingChar,
				obj.paddingColor,
				obj.paddingBGColor
			)
			x, y = term.getCursorPos()
		elseif obj.progress then
			gui.writeProgressBar(obj.progress, obj.lowIsGood)
			x, y = term.getCursorPos()
		elseif obj.text then
			gui.setColor(obj.color)
			gui.setBGColor(obj.bgColor)
			term.write(obj.text)
			x, y = term.getCursorPos()
		end
		if obj.newline then
			x, y = term.getCursorPos()
			term.setCursorPos(1, y + 1)
			y = y + 1
		end
	end
	gui.setColor()
	gui.setBGColor()
	term.setCursorPos(1, y + 1)
end

local buttons = {}

-- Button Data
-- {
-- 	label = string,
-- 	x = number,
-- 	y = number,
-- 	color = color,
-- 	bgColor = color,
-- 	width = number,
-- 	onClick = function
-- }
function gui.addButton(button)
	button.width = button.width or #button.label
	table.insert(buttons, button)
end

function gui.processButtons()
	local event, button, xPos, yPos = os.pullEvent("mouse_click")
	for _, buttonData in ipairs(buttons) do
		if xPos >= buttonData.x and xPos < buttonData.x + buttonData.width and
			yPos >= buttonData.y and yPos <= buttonData.y + 1 then
			buttonData.onClick()
		end
	end
end

function gui.drawButtons()
	for _, buttonData in ipairs(buttons) do
		gui.setColor(buttonData.color or colors.white)
		gui.setBGColor(buttonData.bgColor or colors.black)
		term.setCursorPos(buttonData.x, buttonData.y)
		term.write(buttonData.label)
		term.setCursorPos(buttonData.x, buttonData.y + 1)
		term.write(string.rep("\143", buttonData.width))
	end
	gui.setColor()
	gui.setBGColor()
end

function gui.drawReactorStatus(reactorController, powerStorageController)
	local screenX = term.getSize()

	local isOnline = reactorController.getStatus()
	local heatingRate = reactorController.getHeatingRate()
	local boilEfficiency = reactorController.getBoilEfficiency()
	local fuelPercentage = reactorController.getFuelFilledPercentage()
	local wastePercentage = reactorController.getWasteFilledPercentage()
	local coolantPercentage = reactorController.getCoolantFilledPercentage()
	local heatedCoolantPercentage = reactorController.getHeatedCoolantFilledPercentage()
	local energyPercentage = powerStorageController.getEnergyFilledPercentage()
	local energy = powerStorageController.getEnergy()

	local temperature = reactorController.getTemperature()
	local tempColor = colors.lightBlue
	if temperature <= 600 then
		tempColor = colors.lime
	elseif temperature <= 1000 then
		tempColor = colors.yellow
	elseif temperature <= 1200 then
		tempColor = colors.orange
	else
		tempColor = colors.red
	end

	term.clear()
	term.setCursorPos(1, 1)
	gui.writeFormattedText(
		{ newline = true },
		{
			text = " Fission Reactor ",
			color = colors.yellow,
			centered = true,
			paddingChar = "\140",
			paddingColor = colors.gray,
			newline = true
		},
		{ text = " Status ", color = colors.yellow },
		{
			text = isOnline and "ONLINE" or "OFFLINE",
			color = isOnline and colors.green or colors.red,
			newline = true
		},
		{ text = " Temperature", color = colors.lightBlue },
		{
			text = string.format(" %d \176C", temperature - 272.15),
			color = tempColor,
			newline = true
		},
		{ text = " Heating Rate ", color = colors.red },
		{
			text = reformatInt(heatingRate) .. " mb/t",
			color = colors.orange,
			newline = true
		},
		{ text = " Effeciency ", color = colors.orange },
		{ progress = boilEffeciency, newline = true },
		{
			text = " Fluid Levels ",
			color = colors.yellow,
			centered = true,
			paddingChar = "\140",
			paddingColor = colors.gray,
			newline = true
		},
		{ text = " Fuel           ", color = colors.lime },
		{ progress = fuelPercentage },
		{ text = " Waste          ", color = colors.green },
		{ progress = wastePercentage, lowIsGood = true },
		{ text = " Coolent        ", color = colors.lightBlue },
		{ progress = coolantPercentage },
		{ text = " Heated Coolent ", color = colors.orange },
		{ progress = heatedCoolantPercentage, lowIsGood = true, newline = true },
		{
			text = " Power Storage ",
			color = colors.yellow,
			centered = true,
			paddingChar = "\140",
			paddingColor = colors.gray,
			newline = true
		},
		{ text = " Energy Stored ", color = colors.purple },
		{ text = reformatInt(energy) .. " FE", newline = true },
		{ progress = energyPercentage, lowIsGood = false }
	)

	gui.drawButtons()
end

return gui

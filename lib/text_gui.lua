local util = require("util")

local function reformatInt(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function padStart(text, totalLength, paddingChar)
	paddingChar = paddingChar or " "
	local textLength = #text
	if textLength >= totalLength then
		return text
	end
	local paddingNeeded = totalLength - textLength
	return string.rep(paddingChar, paddingNeeded) .. text
end

local textGui = {
	statusMessage = nil
}

function textGui.setColor(color)
	term.setTextColor(color or colors.white)
end

function textGui.setBGColor(color)
	term.setBackgroundColor(color or colors.black)
end

function textGui.setStatusMessage(message)
	textGui.statusMessage = message
end

function textGui.writeCenteredText(y, text, color, bgColor, paddingChar, paddingColor, paddingBGColor)
	local screenSizeX, _ = term.getSize()
	local textLength = #text
	local startX = math.floor((screenSizeX - textLength) / 2) + 1

	term.setCursorPos(1, y)
	if paddingChar then
		term.clearLine()
		textGui.setColor(paddingColor)
		textGui.setBGColor(paddingBGColor)
		term.write(string.rep(paddingChar, startX))
		term.setCursorPos(1, y)
	end

	textGui.setColor(color)
	textGui.setBGColor(bgColor)
	term.setCursorPos(startX, y)
	term.write(text)

	if paddingChar then
		textGui.setColor(paddingColor)
		textGui.setBGColor(paddingBGColor)
		term.setCursorPos(startX + textLength, y)
		term.write(string.rep(paddingChar, screenSizeX - (startX + textLength) + 1))
	end

	textGui.setColor()
	textGui.setBGColor()

	term.setCursorPos(1, y + 1)
end

function textGui.writeProgressBar(progress, lowIsGood)
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

--- @class TextTable.Text
--- @field text string
--- @field color number
--- @field bgColor number
--- @field newline boolean

--- @class TextTable.Centered
--- @field centered boolean
--- @field text string
--- @field color number
--- @field bgColor number
--- @field paddingChar string
--- @field paddingColor number
--- @field paddingBGColor number
--- @field newline boolean

--- @class TextTable.Progress
--- @field progress number
--- @field lowIsGood boolean
--- @field newline boolean

--- @alias TextTable TextTable.Text | TextTable.Centered | TextTable.Progress

--- @param ... TextTable
function textGui.writeFormattedText(...)
	local x, y = term.getCursorPos()
	local textTable = { ... }
	for i, obj in ipairs(textTable) do
		if obj.centered == true then
			assert(obj.text, "Text entry missing 'text' field at index " .. i)
			textGui.writeCenteredText(
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
			textGui.writeProgressBar(obj.progress, obj.lowIsGood)
			x, y = term.getCursorPos()
		elseif obj.text then
			textGui.setColor(obj.color)
			textGui.setBGColor(obj.bgColor)
			term.write(obj.text)
			x, y = term.getCursorPos()
		end
		if obj.newline then
			x, y = term.getCursorPos()
			term.setCursorPos(1, y + 1)
			y = y + 1
		end
	end
	textGui.setColor()
	textGui.setBGColor()
	term.setCursorPos(1, y + 1)
end

local buttons = {}

--- @class ButtonData
--- @field label string
--- @field x number
--- @field y number
--- @field color number
--- @field bgColor number
--- @field onClick number
--- @field width number

--- @param button ButtonData
function textGui.addButton(button)
	button.width = button.width or #button.label
	table.insert(buttons, button)
end

function textGui.processButtons()
	local event, button, xPos, yPos = os.pullEvent("mouse_click")
	for _, buttonData in ipairs(buttons) do
		if xPos >= buttonData.x and xPos < buttonData.x + buttonData.width and
			yPos >= buttonData.y and yPos <= buttonData.y + 1 then
			buttonData.onClick()
		end
	end
end

function textGui.drawButtons()
	for _, buttonData in ipairs(buttons) do
		textGui.setColor(buttonData.color or colors.white)
		textGui.setBGColor(buttonData.bgColor or colors.black)
		term.setCursorPos(buttonData.x, buttonData.y)
		term.write(buttonData.label)
		-- term.setCursorPos(buttonData.x, buttonData.y + 1)
		-- term.write(string.rep("\143", buttonData.width))
	end
	textGui.setColor()
	textGui.setBGColor()
end

return textGui

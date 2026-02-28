-- Simple Snake Game for ComputerCraft: Tweaked
local w, h = term.getSize()
local snake = { { x = math.floor(w / 2), y = math.floor(h / 2) } }
local dir = { x = 1, y = 0 }
local food = { x = math.floor(w * 0.75), y = math.floor(h / 2) }
local score = 0
local gameOver = false

local function drawBorder()
	term.setBackgroundColor(colors.gray)
	for i = 1, w do
		term.setCursorPos(i, 1)
		term.write(" ")
		term.setCursorPos(i, h)
		term.write(" ")
	end
	for i = 1, h do
		term.setCursorPos(1, i)
		term.write(" ")
		term.setCursorPos(w, i)
		term.write(" ")
	end
	term.setBackgroundColor(colors.black)
end

local function spawnFood()
	repeat
		food.x = math.random(2, w - 1)
		food.y = math.random(2, h - 1)
		local onSnake = false
		for _, seg in ipairs(snake) do
			if seg.x == food.x and seg.y == food.y then
				onSnake = true
				break
			end
		end
	until not onSnake
end

local function draw()
	term.setBackgroundColor(colors.black)
	term.clear()
	drawBorder()

	-- Draw snake
	term.setBackgroundColor(colors.lime)
	for _, seg in ipairs(snake) do
		term.setCursorPos(seg.x, seg.y)
		term.write(" ")
	end

	-- Draw food
	term.setBackgroundColor(colors.red)
	term.setCursorPos(food.x, food.y)
	term.write(" ")

	-- Draw score
	term.setBackgroundColor(colors.black)
	term.setCursorPos(2, 1)
	term.write("Score: " .. score)
end

local function update()
	local head = snake[1]
	local newHead = { x = head.x + dir.x, y = head.y + dir.y }

	-- Check wall collision
	if newHead.x < 2 or newHead.x > w - 1 or newHead.y < 2 or newHead.y > h - 1 then
		gameOver = true
		return
	end

	-- Check self collision
	for _, seg in ipairs(snake) do
		if seg.x == newHead.x and seg.y == newHead.y then
			gameOver = true
			return
		end
	end

	table.insert(snake, 1, newHead)

	-- Check food collision
	if newHead.x == food.x and newHead.y == food.y then
		score = score + 1
		spawnFood()
	else
		table.remove(snake)
	end
end

-- Main game loop
while not gameOver do
	draw()

	local timer = os.startTimer(1)
	local event, key
	repeat
		event, key = os.pullEvent()
	until event == "timer" or event == "key"

	if event == "timer" then
		update()
	elseif event == "key" then
		if key == keys.up and dir.y == 0 then
			dir = { x = 0, y = -1 }
		elseif key == keys.down and dir.y == 0 then
			dir = { x = 0, y = 1 }
		elseif key == keys.left and dir.x == 0 then
			dir = { x = -1, y = 0 }
		elseif key == keys.right and dir.x == 0 then
			dir = { x = 1, y = 0 }
		end
	end
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
print("Game Over!")
print("Final Score: " .. score)

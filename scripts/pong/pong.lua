local screenSizeX, screenSizeY = term.getSize()

local ball = {
	x = 0,
	y = 0,
	motion = { x = 0, y = 0 },
	speed = 0.25 -- Pixels per frame
}

local function resetBall()
	ball.x = screenSizeX / 2
	ball.y = screenSizeY / 2
	ball.motion.x = 0
	ball.motion.y = 0
end

local function startBall()
	ball.motion.x = math.random(0, 1) == 0 and -ball.speed or ball.speed
	ball.motion.y = math.random(0, 1) == 0 and -ball.speed or ball.speed
end

local function draw()
	term.clear()
	term.setCursorPos(math.floor(ball.x), math.floor(ball.y))
	term.write("O")
end

local function updateBall()
	ball.x = ball.x + ball.motion.x
	ball.y = ball.y + ball.motion.y

	if ball.x <= 1 or ball.x >= screenSizeX then
		resetBall()
		startBall()
	end

	if ball.y <= 1 or ball.y >= screenSizeY then
		ball.motion.y = -ball.motion.y
	end
end

local function loop()
	while true do
		draw()

		updateBall()

		os.sleep(0.05)
	end
end


resetBall()
startBall()

loop()

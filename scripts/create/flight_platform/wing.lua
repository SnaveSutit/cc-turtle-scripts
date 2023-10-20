-- wget http://localhost:3000/wing.lua startup.lua
local _, data = turtle.inspect()
if (data.name == "create:sticker") and (not data.state.extended) then
	redstone.setOutput("front", true)
	sleep(0.05)
	redstone.setOutput("front", false)
	sleep(0.05)
	redstone.setOutput("right", true)
	sleep(0.05)
	redstone.setOutput("right", false)
	sleep(0.05)
end

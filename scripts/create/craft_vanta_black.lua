-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/craft_vanta_black.lua startup.lua

local function safeSuck(suckFunc, slot)
	local count = turtle.getItemCount(slot)
	if count < 64 then
		suckFunc(64 - count)
		return true
	end
	return false
end

while true do
	safeSuck(turtle.suckUp, 1)
	safeSuck(turtle.suckUp, 2)
	safeSuck(turtle.suckUp, 3)

	safeSuck(turtle.suckDown, 5)
	safeSuck(turtle.suckDown, 6)
	safeSuck(turtle.suckDown, 7)

	safeSuck(turtle.suckUp, 9)
	safeSuck(turtle.suckUp, 10)
	safeSuck(turtle.suckUp, 11)

	-- turtle.craft()

	-- for i = 1, 16 do
	-- 	turtle.select(i)
	-- 	turtle.drop()
	-- end
end

-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/craft_vanta_black.lua startup.lua

while true do
	turtle.select(1)
	turtle.suckUp()
	turtle.select(2)
	turtle.suckUp()
	turtle.select(2)
	turtle.suckUp()

	turtle.select(5)
	turtle.suckDown()
	turtle.select(6)
	turtle.suckDown()
	turtle.select(7)
	turtle.suckDown()

	turtle.select(9)
	turtle.suckUp()
	turtle.select(10)
	turtle.suckUp()
	turtle.select(11)
	turtle.suckUp()

	turtle.select(4)
	turtle.craft()
	turtle.drop()
end

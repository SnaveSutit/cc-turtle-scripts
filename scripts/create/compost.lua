-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/create/compost.lua startup.lua

local storage_block = "storage_unit"
local rich_soil = "farmersdelight:rich_soil"
local organic_compost = "farmersdelight:organic_compost"
local direction = true


local function refuel()
	print('Refueling...')
	while turtle.getFuelLevel() < 25 do
		turtle.select(1)
		turtle.suckUp()
		turtle.refuel()
	end
end


local function find_zero()
	print('Finding zero...')
	direction = true
	while true do
		if not turtle.forward() then
			turtle.turnLeft()
		else
			local success, data = turtle.inspect()
			if success and data.name:find(storage_block) then
				turtle.turnLeft()
				success, data = turtle.inspect()
				if success and data.name:find(storage_block) then
					turtle.turnLeft()
					turtle.turnLeft()
					return
				end
				turtle.turnRight()
				success, data = turtle.inspect()
				if success and data.name:find(storage_block) then
					turtle.turnRight()
					turtle.turnRight()
					return
				end
			end
		end
	end
end


local function refill_compost()
	print('Refilling compost...')
	turtle.turnLeft()
	turtle.select(2)
	while not turtle.suck() do
		print('Waiting for compost...')
		sleep(10)
	end
	turtle.turnRight()
end


local function empty_soil()
	print('Emptying soil...')
	turtle.turnLeft()
	turtle.turnLeft()
	for i = 3, 16 do
		turtle.select(i)
		if turtle.getItemCount() > 0 then
			while not turtle.drop() do
				print('Waiting for empty soil...')
				sleep(10)
			end
		end
	end
	turtle.turnRight()
	turtle.turnRight()
end


local function has_compost()
	turtle.select(2)
	local data = turtle.getItemDetail()
	if data and data.name == organic_compost then
		return true
	end
	return false
end


local function has_fuel()
	return turtle.getFuelLevel() > 10
end


local function main()
	find_zero()
	empty_soil()
	if not has_compost() then
		refill_compost()
	end
	if not has_fuel() then
		refuel()
	end
	while has_compost() and has_fuel() do
		local success, data = turtle.inspectDown()
		if success and data.name == rich_soil then
			turtle.digDown()
			turtle.select(2)
			turtle.placeDown()
		elseif not success then
			turtle.select(2)
			turtle.placeDown()
		end
		if not turtle.forward() then
			if direction then
				turtle.turnRight()
				if not turtle.forward() then
					return
				end
				turtle.turnRight()
			else
				turtle.turnLeft()
				if not turtle.forward() then
					return
				end
				turtle.turnLeft()
			end
			direction = not direction
		end
	end
end

refuel()
while true do
	main()
end

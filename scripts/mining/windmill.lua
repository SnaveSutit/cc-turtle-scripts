local maxLapCount = 10
local currentLap = 0

local oresUrl = 'https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/data/create-astral-ores.txt'
local oreList = {}
local scannedOres = {}

local function strsplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

local function loadOres()
	local response = http.get(oresUrl)
	local text = response.readAll()
	response.close()
	oreList = strsplit(text, "\n")
end

local function scanOres()
	local scans = {}
	scans.forward = turtle.inspect()
	scans.up = turtle.inspectUp()
	scans.down = turtle.inspectDown()
	turtle.turnLeft()
	scans.left = turtle.inspect()
	turtle.turnRight()
	turtle.turnRight()
	scans.right = turtle.inspect()
	turtle.turnLeft()
end

local function digForwards(blocks)
	for i = 1, blocks do
		turtle.dig("right")
		turtle.forward()
	end
end

local function runNextLap()
end

local function main()
	loadOres()
	print(oreList)
end

main()

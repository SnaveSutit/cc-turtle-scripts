local LIBRARY_PATH = ".lib/"

local function splitVersion(version)
	local parts = {}
	for part in string.gmatch(version, "[^%.]+") do
		table.insert(parts, tonumber(part))
	end
	return parts
end

--- Returns true if version a is newer than version b
local function compareVersion(a, b)
	local aParts = splitVersion(a)
	local bParts = splitVersion(b)

	local maxLength = math.max(#aParts, #bParts)
	for i = 1, maxLength do
		local aPart = aParts[i] or 0
		local bPart = bParts[i] or 0

		if aPart < bPart then
			return false
		elseif aPart > bPart then
			return true
		end
	end
	return false
end

local function installLib(url)
	local fileName = url:match("[^/]+$")
	local filePath = LIBRARY_PATH .. fileName

	print("Installing library: " .. fileName)

	if not fs.exists(LIBRARY_PATH) then
		fs.makeDir(LIBRARY_PATH)
	end

	local response, err = http.get(url)
	if not response then
		error("Failed to fetch library: " .. tostring(err))
	end

	local libContent = response.readAll()

	if fs.exists(filePath) then
		-- print(fileName .. " is already installed.")
		local remoteLib = load(libContent)()
		local localLib = require(filePath)

		if not localLib then
			print("Warning: Unable to load local library " .. fileName .. ". Assuming update is needed.")
		elseif remoteLib._VERSION == nil or localLib._VERSION == nil then
			print("Warning: Unable to determine version for " .. fileName .. ". Assuming update is needed.")
		elseif compareVersion(remoteLib._VERSION or "0.0.0", localLib._VERSION or "0.0.0") then
			print("Updating " .. fileName .. " to version " .. (remoteLib._VERSION or "latest"))
		else
			print(fileName .. " is already installed and up to date.")
			return
		end
	end

	local file = fs.open(filePath, "w")
	file.write(libContent)
	file.close()
end

print("Installing Dependencies...")
installLib("https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/libs/nbs_reader.lua")

print("Installing NBS Player...")
shell.run("wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/nbs-player/nbs_player.lua")

print("\nNBS Player installation complete. Type 'nbs_player' to run the player from the command line.")

local function requireExternal(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename:match("[^%.]+"))
end

---- External Dependencies ----
local state = requireExternal(
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/state_manager.lua")

---- Config ----
local wsURL = "ws://iansenne.com:65123/ws/cc?code="

---- Variables ----
local args = { ... }
local stateFile = ".host_state"
local ws
local defaultState = {
	wsURL = nil,
}

local attemptReconnect = false
local sessionID = string.gsub(args[1], "[^a-zA-Z0-9%-]", "")
if not sessionID then
	attemptReconnect = true
end
print("Session ID: " .. sessionID)

---- Websocket ----
--- @return boolean
local function connectNewSocket()
	local error
	state.wsURL = wsURL .. sessionID
	print("Connecting to " .. state.wsURL .. "...")
	ws, error = http.websocket(state.wsURL)
	if not ws then
		print("Failed to connect to " .. state.wsURL .. ". (" .. error .. ")")
		state.wsURL = nil
		return false
	end
	return true
end

--- @return boolean
local function reconnectSocket()
	print("Attempting to reconnect to " .. state.wsURL .. "...")
	local newSocket, error = http.websocket(state.wsURL)
	if not newSocket then
		print("Failed to reconnect to " .. state.wsURL .. ". (" .. error .. ")" .. " Disconnecting...")
		state.wsURL = nil
		return false
	end
	print("Reconnected!")
	ws = newSocket
	return true
end

local function disconnectSocket()
	print("Disconnecting from " .. state.wsURL .. ".")
	state.wsURL = nil
	pcall(ws.close)
	ws = nil
end

--- @param message string
--- @return boolean, string | nil
local function safeSend(message)
	local success, error = pcall(ws.send, message)
	if not success then
		print("Failed to send message to " .. state.wsURL .. ". (" .. error .. ")")
		disconnectSocket()
		return false, error
	end
	return true
end

--- @return string | boolean, string | nil
local function safeReceive()
	local success, message = pcall(ws.receive)
	if not success then
		print("Failed to receive message from " .. state.wsURL .. ". (" .. message .. ")")
		disconnectSocket()
		return false, message
	end
	return success, message
end

---- File System ----
--- @class FileUpdate
--- @field type "file" | "folder"
--- @field event "create" | "delete" | "update" | nil
--- @field path string
--- @field content string | nil
--- @field modified number | nil

local ignoredPaths = { "^/rom" }
local fileCache = {}

local function isPathIgnored(path)
	for _, ignoredPath in ipairs(ignoredPaths) do
		if path:match(ignoredPath) then
			return true
		end
	end
end

local function getFileSystem()
	local fileSystem = {}
	fileCache = {}
	local function recurse(localPath)
		localPath = localPath or "/"
		for _, path in ipairs(fs.list(localPath)) do
			local newPath = fs.combine(localPath, path)
			if not isPathIgnored(newPath) then
				local attr = fs.attributes(newPath)
				if not attr.isReadOnly then
					if attr.isDir then
						fileSystem[newPath] = {
							type = "folder",
							modified = attr.modified
						}
					else
						local file = fs.open(newPath, "r")
						fileSystem[newPath] = {
							type = "file",
							content = file.readAll(),
							modified = attr.modified
						}
						file.close()
					end
					fileCache[newPath] = attr.modified
				end
			end
		end
	end

	recurse()

	return fileSystem
end

--- @return FileUpdate[]
local function getFileSystemChanges()
	local oldFileCache = fileCache
	fileCache = {}
	--- @type FileUpdate[]
	local changedFiles = {}
	local function recurse(localPath)
		localPath = localPath or "/"
		for _, path in ipairs(fs.list(localPath)) do
			local newPath = fs.combine(localPath, path)
			if not isPathIgnored(newPath) then
				local attr = fs.attributes(newPath)
				if not attr.isReadOnly then
					local cached = oldFileCache[newPath]
					oldFileCache[newPath] = nil
					fileCache[newPath] = attr.modified
					if (cached or 0) < attr.modified then
						if not attr.isDir then
							local file = fs.open(newPath, "r")
							table.insert(changedFiles, {
								type = "file",
								event = cached and "update" or "create",
								path = newPath,
								content = file.readAll(),
								modified = attr.modified
							})
							file.close()
						else
							table.insert(changedFiles, {
								type = "folder",
								event = cached and "update" or "create",
								path = newPath,
								modified = attr.modified
							})
						end
					end
					if attr.isDir then
						recurse(newPath)
					end
				end
			end
		end
	end

	recurse()

	for path, _ in pairs(oldFileCache) do
		table.insert(changedFiles, {
			type = "file",
			event = "delete",
			path = path,
		})
	end

	return changedFiles
end

---- Packets ----
--- @class Packet
--- @field type string
--- @field payload table

--- @class ccFileSystemPacket: Packet
--- @field type "ccFileSystem"
--- @field payload {files: FileUpdate[]}

--- @class ccFileSystemUpdatePacket: Packet
--- @field type "ccFileSystemUpdate"
--- @field payload {files: FileUpdate[]}

--- @class ssFileSystemPushPacket: Packet
--- @field type "ssFileSystemPush"
--- @field payload {files: FileUpdate[]}

---- Main ----
local function initializeConnection()
	if attemptReconnect and state.wsURL then
		reconnectSocket()
	end

	if not ws then
		connectNewSocket()
	end

	if ws then
		local fileSystem = getFileSystem()
		--- @type ccFileSystemPacket
		local packet = {
			type = "ccFileSystem",
			payload = {
				files = fileSystem
			}
		}
		local success, error = safeSend(textutils.serialiseJSON(packet))
		if not success then
			print("Failed to send FS to " .. state.wsURL .. ". (" .. error .. ")")
		end
	else
		error("Failed to connect to websocket server.")
	end
end

local function fileSystemEventWatcher()
	while ws do
		local changes = getFileSystemChanges()
		if #changes > 0 then
			--- @type ccFileSystemUpdatePacket
			local packet = {
				type = "ccFileSystemUpdate",
				payload = {
					files = changes
				}
			}
			local success, error = safeSend(textutils.serialiseJSON(packet))
			if not success then
				print("Failed to send FS changes to " .. state.wsURL .. ". (" .. error .. ")")
			end
		end

		sleep(1)
	end
end

--- @param packet ssFileSystemPushPacket
local function processFileSystemPush(packet)
	for _, fileUpdate in ipairs(packet.payload.files) do
		if fileUpdate.type == "folder" then
			if fileUpdate.event == "create" and not fs.exists(fileUpdate.path) then
				fs.makeDir(fileUpdate.path)
			elseif fileUpdate.event == "delete" and fs.exists(fileUpdate.path) then
				fs.delete(fileUpdate.path)
			end
		else
			if fileUpdate.event == "delete" then
				fs.delete(fileUpdate.path)
			else -- create or update
				local file = fs.open(fileUpdate.path, "w")
				file.write(fileUpdate.content)
				file.close()
			end
		end
	end

	getFileSystem()
end

local function serverMessageWatcher()
	while ws do
		local success, message = safeReceive()
		if not success then
			print("Failed to receive message from " .. state.wsURL .. ". (" .. error .. ")")
			disconnectSocket()
			break
		end
		--- @type Packet
		local packet = textutils.unserialiseJSON(message)
		if not packet then
			print("Failed to parse message from " .. state.wsURL .. ".")
			print("Packet: " .. message)
			break
		end
		if packet.type == "ssFileSystemPush" then
			processFileSystemPush(packet --[[ @as ssFileSystemPushPacket ]])
		end
	end
end

local function main()
	state.load(stateFile, defaultState)

	initializeConnection()

	parallel.waitForAny(fileSystemEventWatcher, serverMessageWatcher)
end

main()

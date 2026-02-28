-- A library for keeping two computers connected.
-- Persists the connection between restarts
local function requireRemote(url)
	local filename = url:match("[^/]+$")
	if not fs.exists(filename) then
		print("Downloading " .. url .. " to " .. filename .. "...")
		shell.run("wget", url, filename)
	end
	return require(filename:match("[^%.]+"))
end

local state = requireRemote(
	"https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/state_manager.lua")

local con = {}

local _timeout = 10
local _channel, _modem

--- @class Connection # A connection to another computer
--- @field send fun(title: string, data: any)
--- @field receive fun(title: string, data: any)
--- @field close fun()

local function startup()
	_modem = peripheral.find("modem", function(name, modem)
		return modem.isWireless()
	end)
	if _modem == nil then
		error("No wireless modem found")
	end

	state.load(".connect_lib_state", { connections = {} })
end

local function open(channel)
	if _modem.isOpen(channel) then
		error("Can't use channel " .. channel .. " because it's already open.")
	end
	_modem.open(channel)
	_channel = channel
end

--- @param timeout number
local function pullModemEvent(timeout)
	local event, timerID
	timerID = os.startTimer(timeout)
	while true do
		event = { os.pullEvent("modem_message") }
		if (event[1] == "timer" and event[2] == timerID) then
			return nil, true
		elseif event[3] == _channel then
			return event[5], false
		end
	end
end

-- Packets are sent as { id, title, protocol, data }
--- @param id number
--- @param title string
--- @param protocol string
--- @param data any
--- @return string | nil reply, string | nil error
local function safeSend(id, title, protocol, data)
	local timerID, reply, timedOut
	local retries = 0
	while retries < 3 do
		_modem.transmit(_channel, _channel, { id, title, protocol, data })
		while true do
			reply, timedOut = pullModemEvent(5)
			if timedOut then
				retries = retries + 1
				break
			elseif type(reply) == "table"
				and reply[1] == id
				and reply[2] == title
				and reply[3] == protocol .. "!!ACK"
			then
				return reply[3]
			end
		end
	end
	return nil, "Timed out"
end

--- @param id number
--- @param title string
--- @param protocol string
--- @param data any
--- @return table | nil reply, string | nil error
local function safeReceive(id, title, protocol, data)
	local timerID, reply, timedOut
	local retries = 0
	while retries < 3 do
		while true do
			reply, timedOut = pullModemEvent(5)
			if timedOut then
				retries = retries + 1
				break
			elseif type(reply) == "table"
				and reply[1] == id
				and reply[2] == title
				and reply[3] == protocol
			then
				_modem.transmit(_channel, _channel, { id, title .. "!!ACK", protocol, data })
				return reply[4], nil
			end
		end
	end
	return nil, "Timed out"
end

--- @param timeout number
con.setTimeout = function(timeout)
	_timeout = timeout
end

--- @param channel number
--- @param protocol string
--- @param password string
--- @param onConnect fun(connection: Connection)
--- @param onDisconnect fun(reason: string)
con.startServer = function(channel, protocol, password, onConnect, onDisconnect)
	open(channel)

	local computers
	while true do
		sleep(1)
	end
end

--- @param channel number
--- @param protocol string
--- @param password string
--- @param onConnect fun(connection: Connection)
--- @param onDisconnect fun(reason: string)
con.startClient = function(channel, protocol, password, onConnect, onDisconnect)
	open(channel)
end

startup()

return con

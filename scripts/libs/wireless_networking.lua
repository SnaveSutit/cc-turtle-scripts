local lib = {}

local _modem, _channel
local _initialized = false

lib.init = function(modem, channel)
	_modem = modem
	_channel = channel
	_modem.open(_channel)
	_initialized = true
end

function string:endswith(self, suffix)
	return self:sub(-suffix:len()) == suffix
end

local function awaitModemMessage(message, connID)
	local event, data
	repeat
		event = { os.pullEvent("modem_message") }
		data = textutils.unserialize(event[5])
	until event[3] == _channel and data.connID == connID and data.message == message
	return data
end

local function sendModemMessage(message, connID, data)
	_modem.transmit(_channel, _channel, textutils.serialize({
		connID = connID,
		message = message,
		data = data
	}))
end

local function awaitTimer(timerID)
	local event
	repeat
		event = { os.pullEvent("timer") }
	until event[2] == timerID
end

lib.request = function(request, timeout, retryRequestInterval)
	if not _initialized then
		error("Networking library not initialized")
	end
	timeout = timeout or 10
	retryRequestInterval = retryRequestInterval or 1
	local timerID, success, data
	local connectionID = os.getComputerID() .. os.epoch("utc") .. math.random(1000, 9999)

	print("Requesting: " .. request)

	local function requestAck()
		sendModemMessage(request, connectionID)
		awaitModemMessage(request .. "!!ACK", connectionID)
		print("Recieved request response: " .. request)
		success = true
	end

	local function requestData()
		data = awaitModemMessage(request .. "!!DATA", connectionID)
		sendModemMessage(request .. "!!COMPLETE", connectionID)
		print("Recieved request completion: " .. request)
		success = true
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	success = false
	while not success do
		timerID = os.startTimer(retryRequestInterval)
		parallel.waitForAny(requestAck, timeoutTimer)
	end
	os.cancelTimer(timerID)

	success = false
	timerID = os.startTimer(timeout)
	parallel.waitForAny(requestData, timeoutTimer)
	if not success then
		error("Request " .. request .. " timed out while waiting for data.")
	end
	os.cancelTimer(timerID)

	return data
end

lib.awaitRequest = function(request, func, timeout)
	local event, data, connID, timerID, success, responseData
	timeout = timeout or 10

	local function sendData()
		sendModemMessage(request .. "!!DATA", connID, responseData)
		awaitModemMessage(request .. "!!COMPLETE", connID)
		print("Recieved request completion: " .. request)
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	while true do
		repeat
			event = { os.pullEvent("modem_message") }
			data = textutils.unserialize(event[5])
		until event[3] == _channel and data.message == request and data.connID ~= nil
		connID = data.connID
		print("Recieved request: " .. request)
		sendModemMessage(request .. "!!ACK", connID)

		responseData = func()

		success = false
		while not success do
			timerID = os.startTimer(timeout)
			parallel.waitForAny(sendData, timeoutTimer)
			success = true
		end
		os.cancelTimer(timerID)
	end
end

return lib

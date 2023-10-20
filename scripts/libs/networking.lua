local lib = {}

local _initialized, _protocal

local function assertInit()
	if not _initialized then
		error("Networking library not initialized")
	end
end

local function awaitTimer(timerID)
	local event
	repeat
		event = { os.pullEvent() }
	until event[1] == "timer" and event[2] == timerID
end

lib.init = function(modem, protocal)
	rednet.open(peripheral.getName(modem))
	_protocal = protocal
	_initialized = true
end

lib.host = function(hostname)
	assertInit()
	rednet.host(_protocal, hostname)
end

lib.send = function(computerID, title, data)
	assertInit()
	local timerID, success

	local function sendRecieve()
		local timerID
		local function trySend()
			rednet.send(computerID, { title, data })

			local senderID, message
			repeat
				senderID, message = rednet.recieve(_protocal)
			until senderID == computerID
				and type(message) == "table"
				and message.title == (title .. "!!ACK")
			success = true
			os.cancelTimer(timerID)
		end
		local function retryTimer()
			awaitTimer(timerID)
		end
		while not success do
			timerID = os.startTimer(1)
			parallel.waitForAny(trySend, retryTimer)
		end
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	timerID = os.startTimer(30)
	parallel.waitForAny(sendRecieve, timeoutTimer)
	if success then
		os.cancelTimer(timerID)
		return true
	end
	return false
end

lib.recieve = function(computerID, title, func)
	assertInit()
	local timerID, success, data

	local function recieveAck()
		local senderID, message
		repeat
			senderID, message = rednet.recieve(_protocal)
		until senderID == computerID
			and type(message) == "table"
			and message.title == (title .. "!!ACK")
		success = true
		os.cancelTimer(timerID)
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	timerID = os.startTimer(30)
	parallel.waitForAny(recieveAck, timeoutTimer)
	if success then
		os.cancelTimer(timerID)
		return true
	end
	return false
end

return lib

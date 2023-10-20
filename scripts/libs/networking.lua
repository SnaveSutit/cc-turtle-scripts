local net = {}

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

net.init = function(modem, protocal)
	rednet.open(peripheral.getName(modem))
	_protocal = protocal
	_initialized = true
end

net.host = function(hostname)
	assertInit()
	rednet.host(_protocal, hostname)
end

net.unhost = function(hostname)
	assertInit()
	rednet.unhost(_protocal, hostname)
end

net.sendTo = function(computerID, title, data)
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

net.recieveFrom = function(computerID, title, func)
	assertInit()
	local timerID, success, data

	local function recieveAck()
		local senderID, message
		repeat
			senderID, message = rednet.recieve(_protocal)
		until senderID == computerID
			and type(message) == "table"
			and message.title == title
		success = true
		os.cancelTimer(timerID)
		if func then
			func(message.data)
		end
		rednet.send(senderID, { title .. "!!ACK" })
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

net.recieve = function(title, func)
	assertInit()
	local timerID, success, data

	local function recieveAck()
		local senderID, message
		repeat
			senderID, message = rednet.recieve(_protocal)
		until
			type(message) == "table"
			and message.title == title
		success = true
		os.cancelTimer(timerID)
		if func then
			func(message.data)
		end
		rednet.send(senderID, { title .. "!!ACK" })
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

net.requestFrom = function(computerID, title, data, func)
	net.sendTo(computerID, title, data)
	return net.recieveFrom(computerID, title .. "!!DATA", func)
end

net.listenForRequestFrom = function(computerID, title, func)
	local data, sendData
	net.recieveFrom(computerID, title, function(_data) data = _data end)
	sendData = func(data)
	net.sendTo(computerID, title .. "!!DATA", sendData)
end

return net

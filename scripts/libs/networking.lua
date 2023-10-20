local net = {}

local _initialized, _protocol
local _timeout = 10

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
	_protocol = protocal
	_initialized = true
end

net.setTimeout = function(timeout)
	_timeout = timeout
end

net.host = function(hostname)
	assertInit()
	rednet.host(_protocol, hostname)
end

net.unhost = function(hostname)
	assertInit()
	rednet.unhost(_protocol, hostname)
end

net.sendTo = function(computerID, title, data)
	assertInit()
	local timerID, success

	local function sendreceive()
		local retryTimerID
		local function trySend()
			rednet.send(computerID, { title, data })
			print("Sent message: " .. title .. " to " .. computerID)

			local senderID, message
			repeat
				senderID, message = rednet.receive(_protocol)
				print("Recieved message: " .. message.title .. " from " .. senderID)
			until senderID == computerID
				and type(message) == "table"
				and message.title == (title .. "!!ACK")
			success = true
			os.cancelTimer(retryTimerID)
		end
		local function retryTimer()
			awaitTimer(retryTimerID)
		end
		while not success do
			retryTimerID = os.startTimer(1)
			parallel.waitForAny(trySend, retryTimer)
		end
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	timerID = os.startTimer(_timeout)
	parallel.waitForAny(sendreceive, timeoutTimer)
	if success then
		os.cancelTimer(timerID)
		return true
	end
	return false
end

net.receiveFrom = function(computerID, title, func)
	assertInit()
	local timerID, success, data

	local function receiveAck()
		local senderID, message
		repeat
			senderID, message = rednet.receive(_protocol)
		until senderID == computerID
			and type(message) == "table"
			and message.title == title
		success = true
		os.cancelTimer(timerID)
		if func then
			func(message.data, senderID)
		end
		rednet.send(senderID, { title .. "!!ACK" })
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	timerID = os.startTimer(_timeout)
	parallel.waitForAny(receiveAck, timeoutTimer)
	if success then
		os.cancelTimer(timerID)
		return true
	end
	return false
end

net.receive = function(title, func)
	assertInit()
	local timerID, success

	local function receiveAck()
		local senderID, message
		repeat
			senderID, message = rednet.receive(_protocol)
			print("Recieved message: " .. message.title .. " from " .. senderID)
		until
			type(message) == "table"
			and message.title == title
		success = true
		os.cancelTimer(timerID)
		if func then
			func(message.data, senderID)
		end
		rednet.send(senderID, { title .. "!!ACK" })
	end

	local function timeoutTimer()
		awaitTimer(timerID)
	end

	timerID = os.startTimer(_timeout)
	parallel.waitForAny(receiveAck, timeoutTimer)
	if success then
		os.cancelTimer(timerID)
		return true
	end
	return false
end

net.requestFrom = function(computerID, title, data, func)
	local success
	success = net.sendTo(computerID, title, data)
	if not success then
		return false
	end
	return net.receiveFrom(computerID, title .. "!!DATA", func)
end

net.listenForRequestFrom = function(computerID, title, func)
	local data, sendData, success
	success = net.receiveFrom(computerID, title, function(_data) data = _data end)
	if not success then
		return false
	end
	sendData = func(data, computerID)
	return net.sendTo(computerID, title .. "!!DATA", sendData)
end

net.listenForRequest = function(title, func)
	local data, sendData, computerID, success
	success = net.receive(title, function(_data, otherID)
		data = _data
		computerID = otherID
	end)
	if not success then
		return false
	end
	sendData = func(data, computerID)
	return net.sendTo(computerID, title .. "!!DATA", sendData)
end

return net

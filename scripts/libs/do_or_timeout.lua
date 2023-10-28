--- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/do_or_timeout.lua

--- @param func function
--- @param timeout number
--- @param timeoutMessage string
--- @return boolean
local function doOrTimeout(func, timeout, timeoutMessage)
	local timerID, eventID, timedOut
	local function timeoutFunc()
		repeat
			_, eventID = os.pullEvent("timer")
		until eventID == timerID
		timedOut = true
	end
	timerID = os.startTimer(timeout)
	parallel.waitForAny(func, timeout)
	if not timedOut then
		os.cancelTimer(timerID)
		return true
	end
	timeoutMessage = timeoutMessage or "Timed out"
	print(timeoutMessage)
	return false
end

return doOrTimeout

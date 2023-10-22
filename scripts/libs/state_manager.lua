local lib = {}
local state = {}

lib.load = function(default)
	if not fs.exists("state") then
		state = default or {}
		lib.save()
		return
	end
	local file = fs.open("state", "r")
	state = textutils.unserialize(file.readAll())
	file.close()
end

lib.save = function()
	local file = fs.open("state", "w")
	file.write(textutils.serialize(state))
	file.close()
end

lib.reset = function(default)
	state = default or {}
	lib.save()
end

lib.get = function(key)
	return state[key]
end

lib.set = function(key, value)
	if state[key] == value then return end
	state[key] = value
	lib.save()
end

return lib

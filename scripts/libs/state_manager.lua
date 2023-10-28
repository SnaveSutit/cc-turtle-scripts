-- wget https://raw.githubusercontent.com/SnaveSutit/cc-turtle-scripts/main/scripts/libs/state_manager.lua

local lib = {}
local _stateID = nil
local _state = {}

--- Loads the state from the file.
--- @param stateID string
--- @param default table | nil
lib.load = function(stateID, default)
	_stateID = stateID
	if not fs.exists(_stateID) then
		print("State file '" .. _stateID .. "' not found, creating a new one...")
		_state = default or {}
		lib.save()
		return
	end
	local file = fs.open(_stateID, "r")
	_state = textutils.unserialize(file.readAll())
	file.close()
end

--- Saves the state to the file.
lib.save = function()
	local file = fs.open(_stateID, "w")
	file.write(textutils.serialize(_state))
	file.close()
end

--- Resets the state to the default.
--- @param default table | nil
lib.reset = function(default)
	_state = default or {}
	lib.save()
end

--- Gets a value from the state.
--- @param key string
--- @return any
lib.get = function(key)
	return _state[key]
end

--- Sets a value in the state.
--- @param key string
--- @param value any
lib.set = function(key, value)
	if _state[key] == value then return end
	_state[key] = value
	lib.save()
end

setmetatable(lib, {
	__index = function(_, key)
		return lib.get(key)
	end,
	__newindex = function(_, key, value)
		lib.set(key, value)
	end
})

return lib

local util = {}

function util.awaitPerepheral(peripheralType)
	local peripheralInstance = peripheral.find(peripheralType)
	while not peripheralInstance do
		print("Waiting for " .. peripheralType .. "...")
		os.sleep(1)
		peripheralInstance = peripheral.find(peripheralType)
	end
	return peripheralInstance
end

return util

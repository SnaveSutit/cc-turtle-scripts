local util = {}

function util.awaitMultiblockPeripheral(peripheralType)
	local peripheralInstance = peripheral.find(peripheralType)
	while not (
			peripheralInstance ~= nil and
			type(peripheralInstance.isFormed) == "function" and
			peripheralInstance.isFormed()
		) do
		print("Waiting for " .. peripheralType .. "...")
		os.sleep(1)
		peripheralInstance = peripheral.find(peripheralType)
	end
	return peripheralInstance
end

return util

-- local link = 'https://www.dropbox.com/scl/fi/w4kwr7yfz9shq1zdbcpqq/500-Chunks-A-Minecraft-Parody-of-500-Miles.dfpwm?rlkey=95qpkfn4zjnbwyrngo715shyf&dl=1'
local link = 'https://www.dropbox.com/scl/fi/zwr1rubui8b1z0wmyqf7g/holy-moly.dfpwm?rlkey=moztk3kr98dvl1tgh0c0y7jdc&dl=1'

local dfpwm = require('cc.audio.dfpwm')
local speaker = peripheral.find('speaker')

local decoder = dfpwm.make_decoder()

local function play(file)
	print('Starting Playback...')
	while true do
		local chunk = file.readLine()
		if not chunk then break end
		local buffer = decoder(chunk)
		while not speaker.playAudio(buffer) do
			os.pullEvent('speaker_audio_empty')
		end
	end
	print('Playback Complete')
end

local function download()
	print('Downloading...')
	local file = http.get(link)
	if file then
		print('Downloaded Successfully!')
		return file
	else
		print('Failed to load audio file')
	end
end

local function main()
	local file = download()
	if file then
		play(file)
	end
end

main()

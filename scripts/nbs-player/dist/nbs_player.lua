local NBS = (function() local NBS = {
	_VERSION = "1.0.0",
	_AUTHOR = "SnaveSutit",
	_DESCRIPTION = "NBS file parser for ComputerCraft",
	parser = {}
}

--- @class NBS.SongMetaData
--- @field name string
--- @field description string
--- @field author string
--- @field originalAuthor string
--- @field length number - The length of the song in ticks
--- @field layerCount number
--- @field tempo number
--- @field isModern? boolean - Indicates if the NBS file is in the modern format
--- @field NBSVersion? number - The version of the NBS format (only present in modern files)
--- @field vanillaInstrumentCount? number - The number of vanilla instruments (only present in modern files)
--- @field loop? boolean - Indicates if the song should loop (only present in modern files)
--- @field maxLoopCount? number - The maximum number of loops (only present in modern files)
--- @field loopStartTick? number - The tick at which the loop starts (only present in modern files)

--- @alias NBS.InstrumentID number
--- @alias NBS.NoteblockID number

--- @class NBS.Note
--- @field key number
--- @field volume number

--- @alias NBS.Tick table<NBS.InstrumentID, table<NBS.NoteblockID, NBS.Note>>

--- @class NBS.Song
--- @field meta NBS.SongMetaData
--- @field ticks table<NBS.InstrumentID, NBS.Tick>

function NBS.parser.short(file)
	return file.read() + file.read() * 256
end

function NBS.parser.int(file)
	return
		file.read() + file.read() * 256
		+ file.read() * 65536
		+ file.read() * 16777216
end

function NBS.parser.string(file)
	local str = ''
	local length = NBS.parser.int(file)
	for i = 1, length do
		local char = file.read()
		if not char then break end
		str = str .. string.char(char)
	end
	return str
end

function NBS.parser.meta(file)
	local meta = {}
	meta.length = NBS.parser.short(file)
	-- If the first two bytes are 0 this is a modern NBS file.
	if meta.length == 0 then
		meta.isModern = true
		meta.NBSVersion = file.read()
		meta.vanillaInstrumentCount = file.read()
		meta.length = NBS.parser.short(file)
	end
	meta.layerCount = NBS.parser.short(file)

	meta.name = NBS.parser.string(file)
	if meta.name == '' then meta.name = "Untitled" end

	meta.author = NBS.parser.string(file)
	if meta.author == '' then meta.author = "Unknown" end

	meta.originalAuthor = NBS.parser.string(file)
	if meta.originalAuthor == '' then meta.originalAuthor = "Unknown" end

	meta.description = NBS.parser.string(file)
	meta.tempo = NBS.parser.short(file) / 100

	-- Skip fields we don't care about
	file.read()          -- Auto-save enabled
	file.read()          -- Auto-save duration
	file.read()          -- Time signature
	NBS.parser.int(file) -- Minutes spent
	NBS.parser.int(file) -- Left clicks
	NBS.parser.int(file) -- Right clicks
	NBS.parser.int(file) -- Note blocks added
	NBS.parser.int(file) -- Note blocks removed
	NBS.parser.string(file) -- MIDI/Schematic file name
	-- More modern meta data
	if meta.isModern then
		meta.loop = file.read()               -- Loop on/off
		meta.maxLoopCount = file.read()       -- Loop count
		meta.loopStartTick = NBS.parser.short(file) -- Loop start tick
	end
	return meta
end

--- @class NBS.ParserOptions
--- @field wrapNotes? boolean

--- @param file table - (fs.FileHandle) The file handle to read from
--- @param song NBS.Song - The song table being constructed
--- @param options? NBS.ParserOptions - Options for parsing the NBS file
function NBS.parser.tick(file, song, options)
	options = options or {}
	--- @type NBS.Tick
	local tick = {}
	local noteblockID = 0
	local jumps = NBS.parser.short(file) -- Number of jumps in this tick
	while jumps > 0 do
		noteblockID = noteblockID + jumps

		local instrument = file.read()
		if not song.meta.isModern and instrument > 9 then
			error("Cannot parse NBS files with custom instruments!")
		elseif instrument > 15 then
			error("Cannot parse NBS files with custom instruments!")
		end
		instrument = instrument + 1 -- Lua tables start at 1

		local note = file.read() - 33
		if options.wrapNotes then
			note = note % 25
		else
			if note < 0 or note > 24 then
				error("Cannot parse NBT files with notes outside the vanilla noteblock range!")
			end
		end

		local volume = 100
		if song.meta.isModern then
			volume = file.read()
		end

		if not tick[instrument] then tick[instrument] = {} end
		tick[instrument][noteblockID] = { key = note, volume = volume }
		-- Skip fields from the modern format we don't care about
		if song.meta.isModern then
			file.read()   -- Panning
			NBS.parser.short(file) -- Pitch Tuning
		end
		-- Read next jump
		jumps = NBS.parser.short(file)
	end
	return tick
end

function NBS.parser.nextTick(file, song)
	-- Add an empty tick for each jump
	local jumps = NBS.parser.short(file)
	for i = 1, jumps - 1 do
		table.insert(song.ticks, {})
	end
	return jumps > 0
end

--- Loads a NBS file from a file handle and returns a song table.
--- @param fileData table - fs.FileHandle
--- @param options? NBS.ParserOptions
function NBS.load(fileData, options)
	options = options or {}

	local song = {
		meta = NBS.parser.meta(fileData),
		ticks = {},
	}

	while NBS.parser.nextTick(fileData, song) do
		local tick = NBS.parser.tick(fileData, song, options)
		table.insert(song.ticks, tick)
		-- Prevent "too long without yielding" error
		os.queueEvent("ONBS_TICK_PARSED")
		os.pullEvent("ONBS_TICK_PARSED")
	end

	return song
end

--- Opens a NBS file from the given path and returns a song table.
--- @param path string - Path to the NBS file
--- @param options NBS.ParserOptions
function NBS.open(path, options)
	local file = fs.open(path, "rb")
	if not file then return nil end
	return NBS.load(file, options)
end

return NBS
 end)()

local SPEAKERS = { peripheral.find("speaker") }
-- local CREATE_SOURCE = peripheral.find("create_source")

if #SPEAKERS < 1 then
	error("No speakers found!")
end

--------------------------------
-- Util
--------------------------------

local function includes(table, value)
	for _, v in pairs(table) do
		if v == value then return true end
	end
	return false
end

local function updateSpeakerList()
	SPEAKERS = { peripheral.find("speaker") }
end

--------------------------------
-- Song Management
--------------------------------

local songList = {}

local function getSongListFromRepo(url)
	local response, err = http.get(url)
	if not response then
		error("Failed to get song list from repo: " .. tostring(err))
	end
	local data = textutils.unserialiseJSON(response.readAll())
	response.close()

	songList = {}
	for _, file in pairs(data) do
		if file.name:sub(-4) == ".nbs" then
			table.insert(songList, {
				name = file.name:sub(1, -5),
				url = file.download_url
			})
		end
	end
end

local function downloadSongData(songListItem)
	local res, err = http.get(songListItem.url, nil, true)
	if not res then
		error("Failed to download song: " .. tostring(err))
	end
	return res
end

local function loadShuffledSong()
	local index = math.random(#songList)
	local songListItem = songList[index]

	local song = NBS.load(downloadSongData(songListItem), { wrapNotes = true })

	if not song then
		error("Failed to load song: " .. tostring(songListItem.name))
	end

	if song.meta.name == "Untitled" then
		song.meta.name = songListItem.name
	end

	return song
end

--------------------------------
-- Playback
--------------------------------

local mainVolume = 100
local drumVolume = 50

local activeSong = nil
local paused = false
local skip = false
local currentTickIndex = 1

local INSTRUMENTS = {
	'harp',
	'bass',
	'basedrum',
	'snare',
	'hat',
	'guitar',
	'flute',
	'bell',
	'chime',
	'xylophone',
	'iron_xylophone',
	'cow_bell',
	'didgeridoo',
	'bit',
	'banjo',
	'pling',
}

local DRUMS = {
	'bass',
	'basedrum',
	'snare',
	'hat',
}

local function buttonClick()
	for _, speaker in ipairs(SPEAKERS) do
		speaker.playSound("ui.button.click")
	end
end

local function sleep(seconds)
	local ticks = seconds * 20
	ticks = math.floor(ticks + 0.5)
	for _ = 1, ticks do os.sleep(0.05) end
end

local function playNote(instrument, volume, key)
	for _, speaker in ipairs(SPEAKERS) do
		-- Volume is a float between 0 and 3.
		speaker.playNote(instrument, 0.03 * volume, key)
	end
end

local function playActiveSong()
	if not activeSong then return end

	currentTickIndex = 1
	for _, tick in ipairs(activeSong.ticks) do
		while paused do os.sleep(0.05) end

		for instrumentIndex, notes in pairs(tick) do
			for _, note in pairs(notes) do
				local instrument = INSTRUMENTS[instrumentIndex]
				local volume = (note.volume or 100) * (0.01 * mainVolume)
				-- Drums have a separate volume control
				if includes(DRUMS, instrument) then
					volume = volume * (0.01 * drumVolume)
				end
				playNote(instrument, volume, note.key)
			end
		end

		currentTickIndex = currentTickIndex + 1
		sleep(1 / activeSong.meta.tempo)
	end

	os.sleep(1)
end

--------------------------------
-- GUI
--------------------------------

local function drawTextAt(x, y, text, color, backgroundColor)
	term.setBackgroundColor(backgroundColor or colors.black)
	term.setCursorPos(x, y)
	term.setTextColor(color or colors.white)
	term.write(text)
end

local function drawCenteredText(text, y, color, bufferChar, bufferColor)
	local screenSizeX, _ = term.getSize()
	local textLength = #text
	local startX = math.floor((screenSizeX - textLength) / 2) + 1

	term.setCursorPos(1, y)
	if bufferChar and bufferColor then
		term.clearLine()
		term.setTextColor(bufferColor)
		term.write(string.rep(bufferChar, startX))
		term.setCursorPos(1, y)
	end

	term.setTextColor(color)
	term.setCursorPos(startX, y)
	term.write(text)

	if bufferChar and bufferColor then
		term.setTextColor(bufferColor)
		term.setCursorPos(startX + textLength, y)
		term.write(string.rep(bufferChar, screenSizeX - (startX + textLength) + 1))
	end
end

local function setInfoText(text, textColor)
	term.setCursorPos(1, 4)
	term.clearLine()
	drawCenteredText(text, 4, textColor, " ", colors.black)
	term.setCursorPos(1, 5)
	term.clearLine()
end

local function drawHorizontalLine(y, char, color)
	local screenSizeX, _ = term.getSize()
	term.setTextColor(color)
	term.setCursorPos(1, y)
	term.write(string.rep(char, screenSizeX))
end

local function drawTimeRemaining()
	if not activeSong then return end

	local totalTicks = activeSong.meta.length
	local ticksPassed = currentTickIndex - 1
	local timePassed = ticksPassed / activeSong.meta.tempo
	local timeRemaining = math.max(0, (totalTicks - ticksPassed + 3) / activeSong.meta.tempo)
	local minutesPassed = math.floor(timePassed / 60)
	local secondsPassed = math.floor(timePassed % 60)
	local minutesRemaining = math.floor(timeRemaining / 60)
	local secondsRemaining = math.floor(timeRemaining % 60)
	local timePassedText = string.format("%02d:%02d", minutesPassed, secondsPassed)
	local timeRemainingText = string.format("%02d:%02d", minutesRemaining, secondsRemaining)

	local screenSizeX = term.getSize()

	drawTextAt(2, 7, timePassedText, colors.lightGray)
	drawTextAt(screenSizeX - 5, 7, timeRemainingText, colors.lightGray)

	local progressBarWidth = screenSizeX - 2
	local progressBarFilled = math.floor((ticksPassed / totalTicks) * progressBarWidth)
	local progressBarEmpty = progressBarWidth - progressBarFilled

	drawTextAt(1, 6, "[", colors.gray)
	drawCenteredText(("#"):rep(progressBarFilled) .. (" "):rep(progressBarEmpty), 6, colors.green)
	drawTextAt(screenSizeX, 6, "]", colors.gray)
end

local function drawNowPlayingSlot()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(1, 1)

	drawCenteredText(" Now Playing ", 2, colors.lightGray, "\140", colors.gray)
	drawHorizontalLine(8, "\131", colors.gray)
end

local function drawScrollingText(text, y, color, speed)
	local screenSizeX, _ = term.getSize()
	if #text <= screenSizeX then
		term.setBackgroundColor(colors.black)
		drawCenteredText(text, y, color, " ", colors.black)
		return
	end

	local loopDelay = 12
	local t = math.floor(os.clock() * speed)
	local offset = math.max(0, (t % (#text + 4 + loopDelay)) - loopDelay)
	local displayText = string.rep(text .. "    ", 2)
	local textToShow = displayText:sub(offset + 1, offset + screenSizeX)

	term.setCursorPos(1, y)
	term.clearLine()
	term.setBackgroundColor(colors.black)
	term.setTextColor(color)
	term.write(textToShow)
end

local function drawNowPlayingTitle()
	if not activeSong then return end

	drawScrollingText(activeSong.meta.name, 4, colors.lime, 4)
	if activeSong.meta.originalAuthor ~= "Unknown"
		and activeSong.meta.originalAuthor ~= activeSong.meta.author
	then
		drawScrollingText("by " .. activeSong.meta.originalAuthor .. " & " .. activeSong.meta.author, 5, colors.yellow, 4)
	else
		drawScrollingText("by " .. activeSong.meta.author, 5, colors.yellow, 4)
	end
	drawTimeRemaining()
end

local screenSizeX, _ = term.getSize()
local BUTTONS = {
	{
		rect = {
			screenSizeX / 2 - 6,
			8,
			4,
			1
		},
		draw = function()
			local screenSizeX, _ = term.getSize()
			term.setBackgroundColor(colors.black)
			term.setTextColor(colors.white)
			term.setCursorPos(screenSizeX / 2 - 5, 8)
			if paused then
				term.write(" |> ")
			else
				term.write(" || ")
			end
		end,
		click = function()
			paused = not paused
		end
	},
	{
		rect = {
			screenSizeX / 2 + 3,
			8,
			4,
			1
		},
		draw = function()
			local screenSizeX, _ = term.getSize()
			term.setBackgroundColor(colors.black)
			term.setTextColor(colors.white)
			term.setCursorPos(screenSizeX / 2 + 4, 8)
			term.write(" >> ")
		end,
		click = function()
			skip = true
		end
	},
}

local function initializeDisplay()
	term.setBackgroundColor(colors.black)
	term.clear()
	drawNowPlayingSlot()

	for _, btn in ipairs(BUTTONS) do
		btn.draw()
	end
end

local function updateDisplay()
	while true do
		drawNowPlayingTitle()
		os.sleep(0.1)
	end
end

local function mouseInput()
	while true do
		local event, button, x, y = os.pullEvent('mouse_click')
		for _, btn in ipairs(BUTTONS) do
			if
				x >= btn.rect[1] and
				x < btn.rect[1] + btn.rect[3] and
				y >= btn.rect[2] and
				y < btn.rect[2] + btn.rect[4]
			then
				buttonClick()
				btn.click()
				btn.draw()
			end
		end

		if skip then
			skip = false
			setInfoText("Song Skipped!", colors.orange)
			break
		end
	end
end

local function main()
	term.clear()

	term.setCursorPos(1, 1)
	term.write("Fetching song list...")

	getSongListFromRepo("https://api.github.com/repos/flytegg/nbs-songs/contents/")

	while true do
		initializeDisplay()

		setInfoText("Downloading...", colors.orange)

		activeSong = loadShuffledSong()
		updateSpeakerList()
		parallel.waitForAny(playActiveSong, updateDisplay, mouseInput)
		os.sleep(1)
	end
end

main()

term.clear()
term.setCursorPos(1, 1)

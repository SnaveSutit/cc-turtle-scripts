local NBS = {
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

-- JSONB decoder
local Common = require(script.Parent.Common)
local base64 = require(script.Parent.Base64)

type Buffer = {
	Offset: number,
	Source: string,
	Length: number,
	IsFinished: boolean,

	read: (Buffer, len: number?, shiftOffset: boolean?) -> string,
	seek: (Buffer, len: number) -> ()
}

local function Buffer(str): Buffer
	local buffer = {}
	buffer.Offset = 0
	buffer.Source = str
	buffer.Length = string.len(str)
	buffer.IsFinished = false	

	function buffer.read(self: Buffer, len: number?, shift: boolean?): string
		local len = len or 1
		local shift = if shift ~= nil then shift else true
		local dat = string.sub(self.Source, self.Offset + 1, self.Offset + len)

		if shift then
			self:seek(len)
		end

		return dat
	end

	function buffer.seek(self: Buffer, len: number)
		local len = len or 1

		self.Offset = math.clamp(self.Offset + len, 0, self.Length)
		self.IsFinished = self.Offset >= self.Length
	end

	return buffer
end


return function(stream: string, structs: {{string}}?): Common.JSON
	local streamBuffer = Buffer(stream)
	local structs = structs or {}
	
	local function readLEB128()
		local result = 0
		local b = 0 -- amount of bits to shift
		local c;

		repeat
			c = string.byte(streamBuffer:read())
			local c2 = bit32.band(c, 0x7F)
			result = bit32.bor(result, bit32.lshift(c2, b))
			b += 7
		until not bit32.btest(c, 0x80)

		return result
	end
	
	local function readString()
		local len = readLEB128()
		return streamBuffer:read(len)
	end
	
	-- identify header type
	local Header = streamBuffer:read(6)
	if Header ~= Common.MAGIC_HEADER then
		-- try to check against Base64 header
		Header ..= streamBuffer:read(2)
		if Header == Common.BASE64_MAGIC_HEADER then
			streamBuffer = Buffer(base64:Decode(streamBuffer.Source))
			streamBuffer:read(6) -- skip over header
		else
			error("Provided file is not JSONB data")
		end
	end

	local version = readLEB128()
	if version < Common.MIN_VERSION or version > Common.MAX_VERSION then
		error("Invalid spec version")
	end
	
	local stringCount = readLEB128()
	local stringTable = table.create(stringCount)
	for i = 1, stringCount do
		stringTable[i] = readString() 
	end
	
	-- begin reading raw data
	local function readDataChunk()
		local typeByte = string.byte(streamBuffer:read())
		if typeByte == Common.ClassIDs["nil"] then
			return nil
		elseif typeByte == Common.ClassIDs.boolean then
			return string.byte(streamBuffer:read()) == 1
		elseif typeByte == Common.ClassIDs.int32 then
			return string.unpack("<i4", streamBuffer:read(4))
		elseif typeByte == Common.ClassIDs.int64 then
			return string.unpack("<i8", streamBuffer:read(8))
		elseif typeByte == Common.ClassIDs.double then
			return string.unpack("<d", streamBuffer:read(8))
		elseif typeByte == Common.ClassIDs.string then
			local tableIdx = readLEB128()
			return stringTable[tableIdx]
		elseif typeByte == Common.ClassIDs.list then
			-- list type
			local listLen = readLEB128()
			local list = table.create(listLen)
			
			for i = 1, listLen do
				table.insert(list, readDataChunk())
			end
			
			return list
		elseif typeByte == Common.ClassIDs.object then
			local objectLen = readLEB128()
			local object = {}
			
			for i = 1, objectLen do
				local keyStringIdx = readLEB128()
				local key = stringTable[keyStringIdx]
				local val = readDataChunk()
				object[key] = val
			end
			
			return object
		elseif typeByte == Common.ClassIDs.struct then
			local structIdx = readLEB128()
			local object = {}
			local keyMap = structs[structIdx]
			
			for _, key in keyMap do
				object[key] = readDataChunk()
			end
			
			return object
		end
	end
	
	return readDataChunk()
end
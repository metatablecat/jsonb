-- JSONB encoder
-- metatablecat
local Common = require(script.Parent.Common)
local base64 = require(script.Parent.Base64)

-- begin iterating over chunks after validing data

local function toLEB128(n: number): string
	local output = ""
	repeat
		local byte = bit32.band(n, 0x7F)
		n = bit32.rshift(n, 7)
		
		if n ~= 0 then
			byte = 0x80 + byte
		end
		
		output ..= string.char(byte)
	until n == 0
	
	return output
end


local VERSION = toLEB128(0)

return function(data: Common.JSON, structPatterns: {[string]: {string}}?, asBase64: boolean?): string
	local output = Common.MAGIC_HEADER .. VERSION
	
	local stringTable = {}
	local realStringTable = {}
	local stringCount = 0
	local structTable = {}
	local structCount = 0
	local rawData = {}
	
	if structPatterns then
		for structKey, structMatch in structPatterns do
			-- cant use clone here because i need to push structCount
			if string.len(structKey) ~= 4 then
				error("Struct keys must be 4 bytes in length")
			end
			
			structCount += 1
			structTable[structCount] = {
				Key = structKey,
				Struct = structMatch
			}
			
		end
	end
	
	local function CheckShapeAgainstStructs(keys)
		for idx, struct in structTable do
			local matching = true
			for _, key in struct.Struct do				
				if not keys[key] then
					matching = false					
					break
				end
			end
			
			if matching then
				return idx, struct.Struct
			end
		end
	end
	
	local function AddStringToStringTable(str: string): number
		local findIdx = stringTable[str]
		if not findIdx then
			stringCount += 1
			findIdx = stringCount
			stringTable[str] = findIdx
			realStringTable[findIdx] = str
		end
		
		return findIdx
	end
	
	local function getDataChunkForBlob(blob: Common.JSON_Valid)	
		local DataChunk = {
			ClassID = 0,
			EncodedData = ""
		}

		local t = typeof(blob)
		if t == "table" then
			local blob = blob :: Common.JSON_Object|Common.JSON_List
			-- handle this differently
			-- dont push data until we know exactly what is what
			local isObject = false
			local keys = {}
			local sizeof = 0
			local sectors = {}
			
			for key, val in blob do
				if not isObject then
					if typeof(key) == "string" then
						isObject = true
					end
				else
					if typeof(key) == "number" then
						error("Can only take one of number or string keys, not both")
					end
				end
				
				if isObject then
					keys[key] = true
				end
				
				local childChunk = getDataChunkForBlob(val)
				sectors[key] = string.char(childChunk.ClassID) .. childChunk.EncodedData
				sizeof += 1
			end
			
			DataChunk.EncodedData = toLEB128(sizeof) .. DataChunk.EncodedData
			-- identify type of this chunk
			local pushKeys = false
			local structEncode = false
			
			if isObject then
				local structIDX, structKeys = CheckShapeAgainstStructs(keys)
				if structIDX then
					-- for structIDX, we need to order the data to respect the layout of the struct
					structEncode = true
					DataChunk.ClassID = Common.ClassIDs.struct
					DataChunk.EncodedData = toLEB128(structIDX)
					
					for _, key in structKeys do
						DataChunk.EncodedData ..= sectors[key]
					end
				else
					-- push key strings to sectors
					DataChunk.ClassID = Common.ClassIDs.object
					pushKeys = true
				end
			else
				-- just push values
				
				DataChunk.ClassID = Common.ClassIDs.list
			end
			
			-- iterate over data and finalise sector
			if not structEncode then
				for key, encodedData in sectors do
					if pushKeys then
						local stringIDX = toLEB128(AddStringToStringTable(key))
						DataChunk.EncodedData ..= stringIDX
					end
					
					DataChunk.EncodedData ..= encodedData
				end
			end
		else
			-- primitive type
			local PrimitiveBinding = Common.ClassIDs[t]
			if not PrimitiveBinding then
				error("Cannot parse type " .. t)
			end
			
			DataChunk.ClassID = PrimitiveBinding

			-- encode raw unless String (since we need to do some funny mapping)
			if PrimitiveBinding == Common.ClassIDs["nil"] then
				local blob = blob :: nil
				-- nil
			elseif PrimitiveBinding == Common.ClassIDs.boolean then
				local blob = blob :: boolean
				-- boolean
				DataChunk.EncodedData = string.char(if blob then 1 else 0)
			elseif PrimitiveBinding == Common.ClassIDs.number then
				local blob = blob :: number
				
				if blob % 1 ~= 0 then
					-- double
					DataChunk.ClassID = Common.ClassIDs.double
					DataChunk.EncodedData = string.pack("<d", blob)
				elseif blob >= -(2^31) and blob <= (2^31)-1 then
					-- int32
					DataChunk.ClassID = Common.ClassIDs.int32
					DataChunk.EncodedData = string.pack("<I4", blob)
				else
					-- int64
					DataChunk.ClassID = Common.ClassIDs.int64
					DataChunk.EncodedData = string.pack("<I8", blob)
				end
			elseif PrimitiveBinding == Common.ClassIDs.string then
				local blob = blob :: string
				
				-- string
				-- do match
				local FindTableBinding = AddStringToStringTable(blob)				
				DataChunk.EncodedData = toLEB128(FindTableBinding)
			end
		end
		
		return DataChunk
	end
	
	local rawChunk = getDataChunkForBlob(data)
	-- begin appending data
	-- Structs
	output ..= toLEB128(structCount)
	for _, struct in structTable do
		output ..= struct.Key
	end
	
	-- Strings
	output ..= toLEB128(stringCount)
	for idx, str in realStringTable do
		local len = toLEB128(string.len(str))
		output ..= len .. str
	end
	
	-- Raw Data
	output ..= string.char(rawChunk.ClassID) .. rawChunk.EncodedData
	
	if asBase64 then
		return base64:Encode(output)
	end
	
	return output
end

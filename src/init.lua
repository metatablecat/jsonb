local JSONB = {}
local Common = require(script.Common)

--[[
	JSONB
	Implementation of that weird Binary JSON spec i made
	
	i dont know if this is worth it lol
	
	encode: (data: string|table, structPatterns: {[string]: {string}}) -> string
	decode: (data: string, structPatterns: {[string]: {string}}) -> string
	-- metatablecat
]]

JSONB.encode = require(script.encode)
JSONB.decode = require(script.decode)
JSONB.reserved = Common.ENCODER_RESERVED_SLOT

return JSONB
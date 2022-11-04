local Common = {}

export type JSON_Valid = nil|boolean|number|string|JSON_List|JSON_Object
export type JSON_Object = {[string]: JSON_Valid}
export type JSON_List = {JSON_Valid}
export type JSON = JSON_Object|JSON_List

Common.ClassIDs = {
	["nil"] = 0,
	["boolean"] = 1,
	
	-- number primitives
	["number"] = 2, --doesn't encode using this but is for matching
	["int32"] = 2,
	["int64"] = 3,
	["double"] = 4,
	
	-- strings
	["string"] = 5,
	-- list and object are funny
	["list"] = 6,
	["object"] = 7,
	["struct"] = 8
}

return Common
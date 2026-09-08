--!strict
--!optimize 2

--[=[

	Roblox: The datastore and the MemoryStore Ledger writes to in a live game.

	DataStoreService and MemoryStoreService behind the shape everything else takes. Fresh is the
	options a read carries when it must not be served from the four second cache a datastore keeps,
	built once and handed back to every caller, since nothing writes to it.

	Return type: A table with New. It answers the Hook shape.
	Example usage:
		local Roblox = require("./Roblox")
		local Held = Roblox.New()
--]=]

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Engine = require("../Util/Engine")

export type Hook = Engine.Hook

local function Open(Name: string): Engine.Store
	return DataStoreService:GetDataStore(Name) :: any
end

local function Budget(Kind: Enum.DataStoreRequestType): number
	return DataStoreService:GetRequestBudgetForRequestType(Kind)
end

local function Cache(Name: string): Engine.Map
	return MemoryStoreService:GetHashMap(Name) :: any
end

local Skip: DataStoreGetOptions? = nil

local function Fresh(): any
	local Made = Skip
	if Made ~= nil then
		return Made
	end

	local Built = Instance.new("DataStoreGetOptions")
	Built.UseCache = false
	Skip = Built
	return Built
end

local Held: Hook = table.freeze({
	Open = Open,
	Budget = Budget,
	Cache = Cache,
	Fresh = Fresh,
})

local function New(): Hook
	return Held
end

return table.freeze({
	New = New,
})

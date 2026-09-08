--!strict
--!optimize 2

--[=[

	Reap: Removes the markers of transactions that are over.

	A pass reads the cleanup list rather than searching the store. A marker goes only once every key
	it named has forgotten its leg. A key it cannot read counts as still holding one. Each pass reads
	a fixed number of names per shard and gives back where it stopped.

	A pass with a Claim asks it before each shard and skips a shard another server holds. A skipped
	shard still counts as walked. A Bounded pass whose Claim cannot reach its map stops after one
	shard and gives back the next one. One server still covers every shard, over as many passes as
	there are shards. Only the background pass is bounded. An operator gets the whole walk.

	Return type: A table with Reap. The type is Reaping.
	Example usage:
		local Reap = require("./Reap")
		local Count, Next = Reap.Reap(TxStore, Lookup)
--]=]

local Clock = require("../../Util/Clock")
local DataStoreWrapper = require("../../Util/DataStoreWrapper")
local Shapes = require("../../Core/Shapes")
local Transactions = require("../../Core/Constants/Transactions")
local Windows = require("../../Core/Constants/Windows")
local Ids = require("../../Encode/Ids")
local Mark = require("../../Encode/Mark")
local Log = require("../../Record/Log")
local LogTypes = require("../../Record/Types")
local Marker = require("./Marker")
local Cleanup = require("./Cleanup")
local Types = require("./Types")

type Record = Shapes.Record<any>
type DataStoreWrapper = DataStoreWrapper.DataStoreWrapper
type Lookup = Types.Lookup
type Claimed = Types.Claimed

export type Bookmark = {
	Shard: number,
	Prefix: string,
	Cursor: string,
}

export type Reaping = {
	Node: string?,
	From: number?,
	Horizon: number?,
	Limit: number?,
	Shards: number?,
	Older: { Shard: number, Back: number, Cursor: Bookmark? }?,
	Afford: (() -> boolean)?,
	Claim: ((Shard: number) -> Claimed)?,
}

type Walk = {
	TxStore: DataStoreWrapper,
	Lookup: Lookup,
	Node: string,
	Shard: number,
	Now: number,
	Older: number,
	Grace: number,
	Room: number,
	Looks: number,
	Looked: number,
	Reaped: number,
	Afford: (() -> boolean)?,
}

local ABSENT: Claimed = { Outcome = Transactions.ABSENT }
table.freeze(ABSENT)

local ONCE: DataStoreWrapper.Limits = { Attempts = 1 }

local function Spent(Record: Record, Txid: string, Gen: string?, Born: number): boolean
	for _, Op in Record.Ops do
		if Op.Tx ~= Txid then
			continue
		end
		if type(Gen) ~= "string" then
			return false
		end

		local Mine = Op.TxGen
		if type(Mine) ~= "string" or Mine == Gen then
			return false
		end
		if type(Op.TxAt) ~= "number" or Op.TxAt >= Born then
			return false
		end
	end
	return true
end

local function Anywhere(Walk: Walk, Name: string): LogTypes.Log
	local Known = Walk.Lookup(Name)
	if Known ~= nil then
		return Known
	end
	return Log.New(Marker.Elsewhere(Name, Walk.TxStore))
end

local function Quiet(Walk: Walk, Txid: string, Keys: any, Gen: string?, Born: number): (boolean, boolean)
	if type(Keys) ~= "string" or #Keys == 0 then
		return false, false
	end

	local Named = Mark.Unpack(Keys)
	if #Named == 0 then
		return false, false
	end

	for _, Held in Named do
		local Store, Key = Mark.Split(Held)
		if Store == nil or Key == nil then
			return false, false
		end

		local Read, Record = pcall(function(): Record
			return (Anywhere(Walk, Store):Read(Key :: string))
		end)
		if not Read or not Spent(Record, Txid, Gen, Born) then
			return false, true
		end
	end

	return true, true
end

local function Gone(Walk: Walk, Txid: string): (boolean, boolean)
	local Read, Value, Info = Walk.TxStore:GetAsync(Txid)
	if not Read then
		return false, false
	end
	if Value == nil then
		return true, false
	end

	if type(Value) == "table" then
		local Held = Value :: Types.Marker
		local Updated = Marker.TouchedAt(Info)
		local Settled = Held.Dead == true or Held.Status == Transactions.ABORTED
		if Walk.Now - Updated < (if Settled then Walk.Grace else Walk.Older) then
			return false, false
		end

		if not Settled then
			local Hushed, Readable = Quiet(Walk, Txid, Held.Keys, Marker.GenOf(Value), Marker.BornAt(Value, 0))
			if not Hushed and Readable then
				return false, false
			end

			if not Hushed and Walk.Now - Updated <= Windows.STUCK then
				warn(
					`Ledger: transaction '{Txid}' names no keys Ledger can read, so nothing can prove it is finished. Ledger reads it again every pass until it is {Windows.STUCK // Windows.DAY} days old. there may be more of these than the one named here. take them off by hand once every key they touched has forgotten them`
				)
				return false, false
			end

			if not Hushed then
				warn(
					`Ledger: transaction '{Txid}' names no keys Ledger can read and nothing has touched it for {Windows.STUCK // Windows.DAY} days. nothing can ever prove it is finished, so it is taken off for good. any part of it still waiting on a key settles as cancelled now, check the audit log`
				)
			end
		end
	end

	if not Walk.TxStore:RemoveAsync(Txid) then
		return false, false
	end
	return true, true
end

local function Sweep(Walk: Walk, Named: string, Looks: number): (number, number)
	local Afford = Walk.Afford
	if Looks <= 0 or (Afford ~= nil and not Afford()) then
		return 0, 0
	end

	local Read, Packed = Walk.TxStore:GetAsync(Named)
	if not Read or type(Packed) ~= "string" then
		return 0, 0
	end

	local Held = Mark.Unpack(Packed)
	local Later: { string } = {}
	local Kept: { string } = {}
	local Room = Walk.Room - Walk.Reaped
	local Reaped = 0
	local Looked = 0

	for Index, Txid in Held do
		if Looked >= Looks or Reaped >= Room or (Afford ~= nil and not Afford()) then
			table.move(Held, Index, #Held, #Later + 1, Later)
			break
		end

		Looked += 1
		local Drop, Took = Gone(Walk, Txid)
		if not Drop then
			table.insert(Kept, Txid)
			continue
		end
		if Took then
			Reaped += 1
		end
	end

	if Looked == 0 and #Held > 0 then
		return 0, 0
	end

	for _, Txid in Kept do
		table.insert(Later, Txid)
	end

	if #Later == 0 then
		Walk.TxStore:RemoveAsync(Named)
		return Reaped, Looked
	end
	if Cleanup.Carry(Walk.TxStore, Walk.Shard, Walk.Node, Later) then
		Walk.TxStore:RemoveAsync(Named)
	end
	return Reaped, Looked
end

local function Full(Walk: Walk, Looks: number): boolean
	return Walk.Reaped >= Walk.Room or Looks <= 0
end

local function Listed(Walk: Walk, Prefix: string, Afford: (() -> boolean)?, Looks: number, From: string?): (boolean, boolean, string?)
	local Ok, Pages = Walk.TxStore:ListKeysAsync(Prefix, Transactions.REAP_PAGE, From, nil, ONCE)
	if not Ok then
		return false, true, nil
	end

	local Book = Pages :: DataStoreKeyPages
	while true do
		for _, Entry in Book:GetCurrentPage() do
			if Full(Walk, Looks) then
				return true, false, Book.Cursor
			end

			local Named = (Entry :: any).KeyName
			local At = Cleanup.At(Named)
			if At == nil or Walk.Now - At < Walk.Grace then
				continue
			end

			local Took, Looked = Sweep(Walk, Named, Looks)
			Walk.Reaped += Took
			Walk.Looked += Looked
			Looks -= Looked
		end

		if Book.IsFinished then
			return false, false, nil
		end
		if Afford ~= nil and not Afford() then
			return false, true, Book.Cursor
		end
		if not pcall(Book.AdvanceToNextPageAsync, Book) then
			return false, true, nil
		end
	end
end

local function Marked(Shard: number, Prefix: string, Cursor: string?): Bookmark?
	if Cursor == nil or Cursor == "" then
		return nil
	end
	return { Shard = Shard, Prefix = Prefix, Cursor = Cursor }
end

local function Reap(TxStore: DataStoreWrapper, Lookup: Lookup, Held: Reaping?): (number, number, boolean, Bookmark?)
	local Asked: Reaping = Held or {}
	local Older = Asked.Horizon or Windows.REAP
	local Walk: Walk = {
		TxStore = TxStore,
		Lookup = Lookup,
		Node = Asked.Node or Ids.Home(),
		Shard = 0,
		Now = Clock.Now(),
		Older = Older,
		Grace = math.min(Older, Windows.REAP_GRACE),
		Room = Asked.Limit or Transactions.REAP_LIMIT,
		Looks = 0,
		Looked = 0,
		Reaped = 0,
		Afford = Asked.Afford,
	}
	local Afford = Asked.Afford
	local Claim = Asked.Claim
	local Base = if type(Asked.From) == "number" then Asked.From % Transactions.SHARDS else Cleanup.Mine(Asked.Node)

	local Count = math.min(Asked.Shards or Transactions.SHARDS, Transactions.SHARDS)
	Walk.Looks = math.max(Transactions.REAP_LOOKS, Walk.Room // Count)
	local Cursor = Asked.Older
	local Bookmark = if Cursor ~= nil then Cursor.Cursor else nil
	local Rotated = false
	local Pending: Bookmark? = Bookmark

	local Step = 0
	while Step < Count do
		if Walk.Reaped >= Walk.Room or Walk.Looked >= Walk.Room or (Afford ~= nil and not Afford()) then
			break
		end

		local Shard = (Base + Step) % Transactions.SHARDS
		Walk.Shard = Shard
		local Lease: Claimed = if Claim ~= nil then Claim(Shard) else ABSENT
		local Left = Walk.Room - Walk.Looked
		local Looks = if Lease.Outcome == Transactions.TAKEN or Shard == Cleanup.Mine(Walk.Node) then Left else math.min(Walk.Looks, Left)
		local Back = if Cursor ~= nil and Cursor.Shard == Shard then Cursor.Back else nil
		local More, Stopped = false, false
		if Pending ~= nil and Pending.Shard == Shard then
			Pending = nil
		end
		if Lease.Outcome ~= Transactions.HELD then
			local Prefixes = Cleanup.Blocks(Shard, Walk.Now, Back)
			for Index, Prefix in Prefixes do
				local From = if Bookmark ~= nil and Bookmark.Shard == Shard and Bookmark.Prefix == Prefix then Bookmark.Cursor else nil
				local Rest
				More, Stopped, Rest = Listed(Walk, Prefix, Afford, Looks, From)
				Pending = Marked(Shard, Prefix, Rest)
				if Back ~= nil and Index == #Prefixes and not Stopped then
					Rotated = true
				end
				if More or Stopped then
					break
				end
			end
		end
		if Lease.Outcome == Transactions.TAKEN and (More or Stopped) then
			Lease.Release()
		end
		if Stopped then
			return Walk.Reaped, Shard, Rotated, Pending
		end

		Step += 1
	end

	return Walk.Reaped, (Base + Step) % Transactions.SHARDS, Rotated, Pending
end

return table.freeze({
	Reap = Reap,
})

--!strict
--!optimize 2

--[=[

	Validate: Refuses each store Ledger.New cannot build.

	It checks the name, the reducer, the default state, the key mode, the hook, the migrations and the
	balance field. A store that is set up wrong throws where it was built. It does not behave wrongly
	on a key months later.

	Return type: A function that throws, and gives back nothing.
	Example usage:
		local Validate = require("./Validate")
		Validate(Options)
--]=]

local Storable = require("../Encode/Storable")
local Api = require("../Core/Api")
local Datastore = require("../Core/Constants/Datastore")
local Shards = require("../Core/Constants/Shards")
local Transactions = require("../Core/Constants/Transactions")
local Windows = require("../Core/Constants/Windows")

type Config<D> = Api.Config<D>

local MAX_NAME = Datastore.MAX_NAME - #Transactions.SUFFIX

local function Sized(Mock: any)
	if type(Mock) ~= "table" then
		return
	end

	for Named in Mock do
		assert(Named == "Players" or Named == "CCU" or Named == "Throttled", `Mock does not take '{tostring(Named)}', only Players, CCU and Throttled`)
	end

	assert(Mock.Players == nil or (type(Mock.Players) == "number" and Mock.Players >= 0), "Mock Players has to be a count of players on this server when you pass one")
	assert(Mock.CCU == nil or (type(Mock.CCU) == "number" and Mock.CCU >= 0), "Mock CCU has to be a count of players in the whole experience when you pass one")
	assert(Mock.Throttled == nil or type(Mock.Throttled) == "boolean", "Mock Throttled has to be true or false when you pass one")
end

local function Named<D>(Options: Config<D>)
	assert(
		type(Options.Name) == "string" and #Options.Name > 0 and #Options.Name <= MAX_NAME,
		`New needs Name, a datastore name of 1 to {MAX_NAME} characters (the transaction store appends {Transactions.SUFFIX})`
	)
	assert(type(Options.Reducer) == "function", "New needs Reducer, a (State, Op) -> State? function")
	assert(type(Options.Default) == "table", "New needs Default, the fresh state table")
	assert(Options.Keys == nil or Options.Keys == "Player" or Options.Keys == "String", `Keys must be "Player" or "String"`)
	local Count = Options.Shards
	assert(
		Count == nil or (type(Count) == "number" and Count == Count // 1 and Count >= 1 and Count <= Shards.MOST),
		`Shards must be a whole number of tally shards from 1 to {Shards.MOST} when you pass one, got {tostring(Count)}`
	)
	local Every = Options.BumpEvery
	assert(
		Every == nil or (type(Every) == "number" and Every > 0 and Every <= Windows.TALLY_CACHE),
		`BumpEvery must be a number of seconds above 0 and at most {Windows.TALLY_CACHE} when you pass one, got {tostring(Every)}`
	)
	assert(
		Options.Mock == nil or type(Options.Mock) == "boolean" or type(Options.Mock) == "table",
		"Mock must be true or false, or a table of Players, CCU and Throttled, and it puts this store on a fake datastore"
	)
	Sized(Options.Mock)
	assert(Options.OnLoadFailed == nil or type(Options.OnLoadFailed) == "function", "OnLoadFailed must be a (Player, Reason) -> boolean function if you pass one")
	assert(Options.OnLoadFailed == nil or Options.Keys ~= "String", `OnLoadFailed only fires for Store:Load, which needs Keys to be "Player"`)
end

local function Hooked<D>(Options: Config<D>)
	local Hook = Options.Hook
	if Hook == nil then
		return
	end

	assert(type(Hook) == "table", "Hook must be a table of Open, Budget and an optional Cache when you pass one")
	assert(type(Hook.Open) == "function", "Hook needs Open, a (Name) -> DataStore function")
	assert(type(Hook.Budget) == "function", "Hook needs Budget, a (RequestType) -> number function")
	assert(
		Hook.Cache == nil or type(Hook.Cache) == "function",
		"Hook Cache must be a (Name) -> MemoryStore map function when you pass one. leave it out to run without a MemoryStore"
	)
end

local function Stores<D>(Options: Config<D>)
	for Key in Options.Default :: any do
		assert(not (type(Key) == "string" and Storable.Bookkeeping(Key)), `Default key '{tostring(Key)}' uses the '_' prefix reserved for Ledger's bookkeeping`)
	end

	local Fits, Unstorable = Storable.Value(Options.Default)
	assert(Fits, `Default cannot be stored: {Unstorable}`)
end

local function Stepped<D>(Options: Config<D>)
	local Steps = Options.Migrations
	if Steps == nil then
		return
	end

	assert(type(Steps) == "table", "Migrations must be an array of steps")
	for Index, Step in Steps do
		assert(type(Step) == "function" or (type(Step) == "table" and type((Step :: any).Apply) == "function"), `migration {Index} must be a function or a table with an Apply function`)
	end
end

local function Balanced<D>(Options: Config<D>)
	local Field = Options.Balance
	if Field == nil then
		return
	end

	assert(type(Field) == "string" and #Field > 0, `Balance must name a field, like "Gold"`)
	assert(type((Options.Default :: any)[Field]) == "number", `Balance names '{Field}' but the Default has no numeric field by that name`)
end

local function Validate<D>(Options: Config<D>)
	assert(type(Options) == "table", "New takes an options table")

	Named(Options)
	Hooked(Options)
	Stores(Options)
	Stepped(Options)
	Balanced(Options)
end

return Validate

--!strict
--!optimize 2

--[=[

	Counting: What a store says about itself, rather than about a key.

	Stats reads back the counts a store keeps anyway: requests spent, MemoryStore calls that did not
	answer, sessions live here, keys copied, keys the sweep is holding. Every one is a running total
	for the life of the store rather than a rate, so two reads and a subtraction give a window.
	Return type: The case file.
	Example usage:
		Add a case with Cases.Case, then run zune run zune/Cases.luau counting
--]=]

local Suite = require("../Suite")

type Case = Suite.Case

local Cases = Suite.File("Counting")

Cases.Case("a store hands back the counts it was keeping anyway", function(T: Case)
	local Bank = T:Bank()
	local Before = Bank.Store:Stats()

	Bank.Store:Edit("counted", "Fund", { Amount = 5 }):Wait()
	Bank.Store:Peek("counted"):Wait()
	local After = Bank.Store:Stats()

	T:Ok("requests, which only ever go up", After.Requests > Before.Requests)
	T:Is("marker requests, since nothing here opened a transaction", After.Markers, Before.Markers)
	T:Is("sessions live on this server, since this store is keyed by string", After.Loaded, 0)
	T:Is("keys the sweep is following, since nothing was left unfinished", After.Repairing, 0)
	T:Ok("misses, which cannot be negative", After.Misses >= 0)
end)

Cases.Case("stats count the keys a store follows and the ones the sweep holds for it", function(T: Case)
	local Bank = T:Bank()
	Bank:Seed("watched", { Gold = 10 })
	Bank.Store:Follow("watched"):Subscribe(function() end)
	Bank.Store.Sweep:Add(Bank.Store:Swept(), "stranded")

	local Held = Bank.Store:Stats()

	T:Is("keys this store holds a copy of", Held.Followed, 1)
	T:Is("keys the sweep is following for it", Held.Repairing, 1)
end)

--!strict
--!optimize 2

--[=[

	Diagnosing: What one key looks like to someone asking why it will not take a write.

	Diagnose answers why a key is the way it is, in the terms the refusals are written in: what is
	parked on it, what stops it compacting, how long its log is, whether it is entombed. It reads and
	folds and touches nothing else.
	Return type: The case file.
	Example usage:
		Add a case with Cases.Case, then run zune run zune/Cases.luau diagnosing
--]=]

local Suite = require("../Suite")

type Case = Suite.Case

local Cases = Suite.File("Diagnosing")

Cases.Case("a diagnosis of a key with nothing wrong with it", function(T: Case)
	local Bank = T:Bank()
	Bank:Seed("plain", { Gold = 100, Touches = 0 })

	local Held = Bank.Store:Diagnose("plain"):Wait()

	T:Is("the key it answers about", Held.Key, "plain")
	T:Is("transactions parked on it", #Held.Parked, 0)
	T:Is("what stops it compacting", Held.Blocking, nil)
	T:Is("whether it is entombed", Held.Entombed, false)
	T:Is("money set aside on it", Held.Held, 0)
	T:Ok("the bytes its state takes, which it knows without folding", Held.StateBytes > 0)
end)

Cases.Case("a diagnosis names the transaction parked on a key", function(T: Case)
	local Bank = T:Bank()
	Bank:Seed("stuck", { Gold = 100, Touches = 0 })
	Bank:Park("stuck", { Id = "tx:why1:1", Kind = "Give", Amount = -30, Tx = "why1" })

	local Held = Bank.Store:Diagnose("stuck"):Wait()

	T:Is("transactions parked on it", #Held.Parked, 1)
	T:Is("the one it names", Held.Parked[1], "why1")
	T:Is("ops in its log, the parked leg", Held.Ops, 1)
	T:Is("what stops it compacting, which a parked key is not asked", Held.Blocking, nil)
end)

Cases.Case("a diagnosis names the op kind that stops a key compacting", function(T: Case)
	local Bank = T:Bank()
	Bank:Seed("blocked", { Gold = 100, Touches = 0 })
	Bank:Append("blocked", { { Id = "unknown1", Kind = "SomethingThisBuildNeverApplies" } })

	local Held = Bank.Store:Diagnose("blocked"):Wait()

	T:Is("what stops it compacting", Held.Blocking, "SomethingThisBuildNeverApplies")
	T:Is("transactions parked on it", #Held.Parked, 0)
end)

Cases.Case("a diagnosis says a key is entombed and when it was erased", function(T: Case)
	local Bank = T:Bank()
	Bank:Seed("gone", { Gold = 100, Touches = 0 })
	T:Ok("erasing it", (Bank.Store:Erase("gone"):Wait()))

	local Held = Bank.Store:Diagnose("gone"):Wait()

	T:Is("whether it is entombed", Held.Entombed, true)
	T:Is("the time it was erased", type(Held.Erased), "number")
end)

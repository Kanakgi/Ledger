--!strict
--!optimize 2

--[=[

	Telling: What a store says about itself, rather than about a key.

	Everything Ledger warns about goes through one place, so a game can take it and put it wherever
	it keeps its logging. A listener that throws does not get to swallow the message it was handed.
	Return type: The case file.
	Example usage:
		Add a case with Cases.Case, then run zune run zune/Cases.luau telling
--]=]

local Suite = require("../Suite")

local Ledger = require("../../src") :: any
local Report = require("../../src/Core/Report")

type Case = Suite.Case

local Cases = Suite.File("Telling")

Cases.Case("what Ledger says out loud can be handed to the game instead", function(T: Case)
	local Heard: { string } = {}
	Ledger.OnDiagnostic(function(Message: string)
		table.insert(Heard, Message)
	end)
	Report.Say("Ledger: the first thing said")
	Report.Say("Ledger: the second thing said")
	Ledger.OnDiagnostic(nil)
	Report.Say("Ledger: said after letting go, which belongs on the output")

	T:Is("things the listener was handed", #Heard, 2)
	T:Is("the first of them, word for word", Heard[1], "Ledger: the first thing said")
	T:Is("the second", Heard[2], "Ledger: the second thing said")
	T:Ok("nothing more once the listener is let go", Heard[3] == nil)
end)

Cases.Case("a listener that throws loses nothing and is not asked to hold the line", function(T: Case)
	local Reached = 0
	Ledger.OnDiagnostic(function()
		Reached += 1
		error("the listener is broken", 0)
	end)
	Report.Say("Ledger: said into a listener that throws")
	Report.Say("Ledger: said into it a second time")
	Ledger.OnDiagnostic(nil)

	T:Is("times the listener was reached, so one throw does not put it aside", Reached, 2)
	T:Warns("the throw, said out loud", "the function given to OnDiagnostic threw", 2)
	T:Warns("the message it was given, said behind the throw", "said into a listener that throws", 1)
end)

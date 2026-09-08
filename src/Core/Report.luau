--!strict
--!optimize 2

--[=[

	Report: Where everything Ledger says out loud goes.

	Ledger warns about a lot: a write it could not make, a transfer it is holding, a key it gave up
	repairing, a reducer that misbehaved. On a live server those go to the output and nowhere else,
	which is no use to a game that wants them in its own logging. Listen points them somewhere else
	instead, and nothing changes for a game that never calls it.

	A sink that throws is not allowed to swallow the message it was given. The throw is said out
	loud once and the message goes to the output behind it, so a broken sink loses nothing.

	Nothing here requires anything else, so any file can say something without minding what it is
	already holding.

	Return type: A table with Say and Listen.
	Example usage:
		local Report = require("../Core/Report")
		Report.Say(`Ledger: could not read '{Key}'`)
--]=]

type Sink = (Message: string) -> ()

local Held: Sink? = nil

local function Listen(Heard: Sink?)
	assert(Heard == nil or type(Heard) == "function", "OnDiagnostic takes a function of one string, or nothing to put the messages back on the output")
	Held = Heard
end

local function Say(Message: string)
	local Sink = Held
	if Sink == nil then
		warn(Message)
		return
	end

	local Ok, Raised = pcall(Sink, Message)
	if Ok then
		return
	end

	warn(`Ledger: the function given to OnDiagnostic threw, so this went to the output instead: {Raised}`)
	warn(Message)
end

return table.freeze({
	Say = Say,
	Listen = Listen,
})

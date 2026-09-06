--!strict
--!optimize 2

--[=[

	SetInterval: Calls a function again after each interval.

	The function runs on its own thread, on the scheduler it was handed, and cancelling that thread
	stops it. Offset waits a different amount before the first call, so timers started together do
	not stay together. A function that hands back a number of seconds is run next after that many,
	and one that hands back nothing keeps the interval it had.

	Return type: A function that gives back the thread.
	Example usage:
		local SetInterval = require("./SetInterval")
		local Ticker = SetInterval(Scheduler, 30, Save)
		Scheduler.Cancel(Ticker)
--]=]

local Engine = require("./Engine")
local Messages = require("../Core/Constants/Messages")

local function SetInterval(Scheduler: Engine.Scheduler, Seconds: number, Callback: (Count: number) -> ...number?, Offset: number?): thread
	return Scheduler.Spawn(function()
		local Count = 0
		local Interval = Seconds
		if Offset ~= nil and Offset > 0 then
			Scheduler.Wait(Offset)
		end

		while true do
			Scheduler.Wait(Interval)
			Count += 1
			local Ok, Next = pcall(Callback, Count)
			if not Ok then
				warn(`{Messages.ACCUSED} a job Ledger runs on a timer threw, and it keeps running. please report this: {Next}`)
			elseif type(Next) == "number" and Next > 0 then
				Interval = Next
			end
		end
	end)
end

return SetInterval

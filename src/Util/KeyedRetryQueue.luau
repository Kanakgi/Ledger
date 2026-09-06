--!strict
--!optimize 2

--[=[

	KeyedRetryQueue: Keeps the writes to one key in order.

	Each key gets its own queue, so a retry cannot move in front of a write that came first. The
	Direct flag sends a call straight through with no queue at all.

	Return type: A table with Run and SkipAllToLastEnqueued.
	Example usage:
		local Queue = require("./KeyedRetryQueue")
		local Ok, Value = Queue.Run(State, "key", Call)
--]=]

local Engine = require("./Engine")
local ThreadQueue = require("./ThreadQueue")
local RetryAsync = require("./RetryAsync")

type ThreadQueue = ThreadQueue.ThreadQueue

export type Handler = (() -> ...any) -> (boolean, ...any)

export type Limits = RetryAsync.Limits

export type State = {
	Scheduler: Engine.Scheduler,
	Attempts: number?,
	Constant: number?,
	Exponent: number?,
	Jitter: number?,
	Direct: boolean?,
	Queues: { [string]: ThreadQueue },
}

local function RunUnqueued(State: State, Operation: () -> ...any, Handler: Handler?, Limits: Limits?): ...any
	return RetryAsync(State.Scheduler, Operation, Limits or State, Handler)
end

local function Run(State: State, Key: string, Operation: () -> ...any, Handler: Handler?, Limits: Limits?): ...any
	if State.Direct then
		return RunUnqueued(State, Operation, Handler, Limits)
	end

	return ThreadQueue.Keyed(State.Queues, State.Scheduler, Key, function()
		return RunUnqueued(State, Operation, Handler, Limits)
	end)
end

local function SkipAllToLastEnqueued(State: State)
	for _, Queue in State.Queues do
		Queue:SkipToLastEnqueued()
	end
end

return table.freeze({
	Run = Run,
	SkipAllToLastEnqueued = SkipAllToLastEnqueued,
})

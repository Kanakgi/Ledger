--!strict
--!optimize 2

--[=[

	Shapes: The shapes a datastore holds.

	An op, the record one key holds, and the state a fold gives back. Folded names Ledger's own three
	fields and leaves the game's own open. Held is one entry of the money set aside. A Diagnosis is
	what one key looks like to someone asking why it will not take a write.

	Return type: An empty table. The types are Op, Record, HistoryEntry, KeysMode, KeyLike, Held, Folded, Reducer, Migration, Diagnosis and Mocked.
	Example usage:
		local Shapes = require("./Shapes")
		type Op = Shapes.Op
--]=]

export type Op = {
	Id: string,
	Kind: string,
	[any]: unknown,
}

export type Record<S> = {
	Snapshot: S?,
	Bytes: number?,
	Ops: { Op },
	Seen: { string },
	Version: number?,
	Floor: number?,
	Envelope: number?,
	Erased: number?,
}

export type HistoryEntry = {
	Version: string,
	At: number,
	Deleted: boolean,
}

export type KeysMode = "Player" | "String"

export type KeyLike = number | string

export type Held = {
	To: KeyLike,
	Amount: number,
	At: number?,
	Field: string?,
}

export type Folded = {
	_Held: { [string]: Held }?,
	_Received: { [string]: number | string }?,
	_Tally: { [string]: number }?,
	[any]: any,
}

export type Reducer<S> = (State: S, Op: Op) -> S?

export type Migration = ((State: any) -> any) | { Apply: (State: any) -> any, Compatible: boolean? }

export type Diagnosis = {
	Key: string,
	Ops: number,
	Seen: number,
	LogBytes: number,
	StateBytes: number,
	Version: number?,
	Floor: number?,
	Erased: number?,
	Entombed: boolean,
	Overgrown: boolean,
	Parked: { string },
	Blocking: string?,
	Held: number,
	Names: number,
}

export type Mocked = {
	Players: number?,
	CCU: number?,
	Throttled: boolean?,
}

return table.freeze({})

--!strict
--!optimize 2

--[=[
	Follows: Where a copy of a key lives, in names.

	A followed key has one MemoryStore item per key. It holds the game's fields of the record, the
	stamp the datastore put on that record, and the time it was folded. MAP is the map those items
	live in. ROOM is what the item's own fields take beside the state, so a state has to fit under
	the item cap less that.

	Return type: A table with MAP and ROOM.
	Example usage:
		local Follows = require("./Follows")
		local Copier = Wrapper.New(Follows.MAP, Turn, Hook)
--]=]

return table.freeze({
	MAP = "Ledger_Copy",
	ROOM = 128,
})

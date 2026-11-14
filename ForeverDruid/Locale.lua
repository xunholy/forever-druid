-- Text lookup. Forever Druid's own text is English only, on every client: ns.L returns the string
-- it's asked for. Spell and item names never go through here; they come from the client, so macros
-- and spell labels still follow the player's language.

local _, ns = ...

ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})

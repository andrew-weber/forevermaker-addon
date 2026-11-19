-- Apply quests watch wrote into InboxData.lua. The client reads this file on reload and does not write it back.

function ForeverMaker.ClientGame()
	if type(GetBuildInfo) ~= "function" then
		return nil
	end
	local interface = select(4, GetBuildInfo())
	if interface == 16001 then
		return "forever"
	end
	if type(interface) == "number" then
		return "classic"
	end
	return nil
end

function ForeverMaker.ApplyInbox(db, game)
	if type(db) ~= "table" or type(ForeverMakerInbox) ~= "table" then
		return 0
	end
	local changed = 0
	for _, entry in ipairs(ForeverMakerInbox) do
		local text = nil
		local entryGame = nil
		if type(entry) == "string" then
			text = entry
		elseif type(entry) == "table" then
			text = entry.text
			entryGame = entry.game
		end
		if type(entryGame) == "string" and type(game) == "string" and entryGame ~= game then
			text = nil
		end
		if type(text) == "string" then
			local quest, err = ForeverMaker.Parse(text)
			if quest and not err then
				local result = ForeverMaker.Apply(db, quest)
				if result == "saved" or result == "replaced" then
					changed = changed + 1
				end
			end
		end
	end
	return changed
end

-- Apply quests watch wrote into InboxData.lua. The client reads this file on reload and does not write it back.
-- An entry names the character it belongs to. A quest this inbox delivered earlier is removed when it is no longer listed.

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

local function CharacterMatches(entry, character)
	if type(entry.name) ~= "string" then
		return true
	end
	if type(character) ~= "table" or entry.name ~= character.name or type(character.realm) ~= "string" then
		return false
	end
	if type(entry.surname) == "string" then
		return entry.surname == character.realm
	end
	if type(entry.realm) == "string" then
		return entry.realm == character.realm
	end
	return false
end

local function DropQuest(db, id)
	db.quests[id] = nil
	if type(db.order) ~= "table" then
		return
	end
	local order = {}
	for _, kept in ipairs(db.order) do
		if kept ~= id then
			order[#order + 1] = kept
		end
	end
	db.order = order
end

function ForeverMaker.ApplyInbox(db, game, character)
	if type(db) ~= "table" or type(db.quests) ~= "table" or type(ForeverMakerInbox) ~= "table" then
		return 0
	end
	local changed = 0
	local keep = {}
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
		if type(entry) == "table" and not CharacterMatches(entry, character) then
			text = nil
		end
		if type(text) == "string" then
			local quest, err = ForeverMaker.Parse(text)
			if quest and not err then
				local result = ForeverMaker.Apply(db, quest)
				if db.quests[quest.id] then
					db.quests[quest.id].inbox = true
					db.quests[quest.id].inboxGame = entryGame or game
					keep[quest.id] = true
				end
				if result == "saved" or result == "replaced" then
					changed = changed + 1
				end
			end
		end
	end
	for id, quest in pairs(db.quests) do
		if type(quest) == "table" and quest.inbox and not keep[id] and (quest.inboxGame == nil or quest.inboxGame == game) then
			DropQuest(db, id)
		end
	end
	return changed
end

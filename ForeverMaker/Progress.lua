-- Count a PARTY_KILL against kill goals.
-- The client delivers this event for the player and for the other four party members.
-- This first build counts every one of those blows. A hunter pet's blow does not arrive here.

ForeverMaker = ForeverMaker or {}

local seen = {}

function ForeverMaker.ResetSeen()
	seen = {}
end

function ForeverMaker.CreatureId(guid)
	if type(guid) ~= "string" then
		return nil
	end
	local parts = {}
	for part in string.gmatch(guid, "[^%-]+") do
		parts[#parts + 1] = part
	end
	if parts[1] ~= "Creature" and parts[1] ~= "Vehicle" then
		return nil
	end
	if not parts[6] or not string.match(parts[6], "^%d+$") then
		return nil
	end
	return tonumber(parts[6])
end

function ForeverMaker.CreditKill(db, creatureId, victimGuid)
	if type(db) ~= "table" or type(db.quests) ~= "table" or type(creatureId) ~= "number" then
		return 0
	end
	if type(victimGuid) == "string" then
		if seen[victimGuid] then
			return 0
		end
		seen[victimGuid] = true
	end

	local hits = 0
	for _, quest in pairs(db.quests) do
		if type(quest) == "table" and type(quest.goals) == "table" then
			for _, goal in ipairs(quest.goals) do
				if goal.kind == "kill" and goal.gameId == creatureId and type(goal.count) == "number" and type(goal.quantity) == "number" and goal.count < goal.quantity then
					goal.count = goal.count + 1
					hits = hits + 1
				end
			end
		end
	end
	return hits
end

function ForeverMaker.GoalsComplete(quest)
	if type(quest) ~= "table" or type(quest.goals) ~= "table" or #quest.goals == 0 then
		return false
	end
	for _, goal in ipairs(quest.goals) do
		if type(goal.count) ~= "number" or type(goal.quantity) ~= "number" or goal.count < goal.quantity then
			return false
		end
	end
	return true
end

-- completed is part of the one quest record a later upload sends.
-- at, character, realm, and level travel with the quest id, revision, and goal counts.
function ForeverMaker.NoteCompletion(quest, when, character, realm, level)
	if type(quest) ~= "table" then
		return
	end
	if not ForeverMaker.GoalsComplete(quest) then
		quest.completed = nil
		return
	end
	if type(quest.completed) == "table" and type(quest.completed.at) == "number" then
		return
	end
	if type(when) ~= "number" or type(character) ~= "string" or character == "" or type(level) ~= "number" then
		return
	end
	if type(realm) ~= "string" then
		realm = ""
	end
	quest.completed = {
		at = when,
		character = character,
		realm = realm,
		level = level,
	}
end

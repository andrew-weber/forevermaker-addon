-- Count a PARTY_KILL against kill goals.
-- The client delivers this event for the player and for the other four party members.
-- This first build counts every one of those blows. A hunter pet's blow does not arrive here.
-- A secret victim guid has no creature id. The experience sentence can name that blow.

ForeverMaker = ForeverMaker or {}

local seen = {}
local pendingBlows = {}
local pendingNames = {}
local recentIdentified = nil
local PAIR_WINDOW = 3

function ForeverMaker.ResetSeen()
	seen = {}
	pendingBlows = {}
	pendingNames = {}
	recentIdentified = nil
end

function ForeverMaker.KillClock(now)
	if type(now) == "number" then
		return now
	end
	if type(GetTime) == "function" then
		local ok, clock = pcall(GetTime)
		if ok and type(clock) == "number" then
			return clock
		end
	end
	return os.time()
end

function ForeverMaker.HiddenKill(guid)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, guid)
		if ok and secret then
			return true
		end
	end
	return guid == nil
end

function ForeverMaker.NormalizeCreatureName(name)
	if type(name) ~= "string" then
		return nil
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	name = string.gsub(name, "\226\128\153", "'")
	name = string.lower(name)
	if name == "" then
		return nil
	end
	return name
end

local function FormatPattern(fmt)
	local out, order, i = {}, {}, 1
	while i <= #fmt do
		local c = string.sub(fmt, i, i)
		if c == "%" then
			local pos, conv = string.match(string.sub(fmt, i), "^%%(%d)%$([sd])")
			local skip = 4
			if not conv then
				conv = string.match(string.sub(fmt, i), "^%%([sd])")
				skip = 2
			end
			if conv then
				order[#order + 1] = tonumber(pos) or (#order + 1)
				if conv == "s" then
					out[#out + 1] = "(.-)"
				else
					out[#out + 1] = "([%d%.,]+)"
				end
				i = i + skip
			elseif string.sub(fmt, i + 1, i + 1) == "%" then
				out[#out + 1] = "%%"
				i = i + 2
			else
				out[#out + 1] = "%%"
				i = i + 1
			end
		elseif string.find(c, "[%(%)%.%+%-%*%?%[%]%^%$]") then
			out[#out + 1] = "%" .. c
			i = i + 1
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	return "^" .. table.concat(out), order
end

function ForeverMaker.XpKillName(text)
	if type(text) ~= "string" then
		return nil
	end
	local fmt = COMBATLOG_XPGAIN_FIRSTPERSON
	local pattern, order
	if type(fmt) == "string" and fmt ~= "" then
		pattern, order = FormatPattern(fmt)
	else
		pattern, order = "^(.-) dies, you gain [%d%.,]+ experience", { 1 }
	end
	local caps = { string.match(text, pattern) }
	if #caps == 0 then
		return nil
	end
	local args = {}
	for index, argIndex in ipairs(order) do
		args[argIndex] = caps[index]
	end
	return ForeverMaker.NormalizeCreatureName(args[1]) and args[1] or nil
end

local function prunePending(now)
	local function keep(list)
		local kept = {}
		for _, item in ipairs(list) do
			if now - item.time <= PAIR_WINDOW then
				kept[#kept + 1] = item
			end
		end
		return kept
	end
	pendingBlows = keep(pendingBlows)
	pendingNames = keep(pendingNames)
	if recentIdentified and now - recentIdentified > PAIR_WINDOW then
		recentIdentified = nil
	end
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

function ForeverMaker.MeetsLevelLimit(quest, level)
	local constraints = type(quest) == "table" and quest.constraints
	if type(constraints) ~= "table" or #constraints == 0 then
		return true
	end
	if type(level) ~= "number" then
		return false
	end
	for _, limit in ipairs(constraints) do
		if type(limit) ~= "table" or limit.kind ~= "level" or limit.comparison ~= "<" or type(limit.level) ~= "number" then
			return false
		end
		if level >= limit.level then
			return false
		end
	end
	return true
end

local function CreditMatching(db, level, victimGuid, matches)
	if type(db) ~= "table" or type(db.quests) ~= "table" then
		return 0, {}
	end
	if type(victimGuid) == "string" then
		if seen[victimGuid] then
			return 0, {}
		end
		seen[victimGuid] = true
	end

	local hits = 0
	local blocked = {}
	for _, quest in pairs(db.quests) do
		if type(quest) == "table" and type(quest.goals) == "table" then
			local allowed = ForeverMaker.MeetsLevelLimit(quest, level)
			local matched = false
			for _, goal in ipairs(quest.goals) do
				if goal.kind == "kill" and matches(goal) and type(goal.count) == "number" and type(goal.quantity) == "number" and goal.count < goal.quantity then
					matched = true
					if allowed then
						goal.count = goal.count + 1
						hits = hits + 1
					end
				end
			end
			if matched and not allowed then
				blocked[#blocked + 1] = quest
			end
		end
	end
	return hits, blocked
end

function ForeverMaker.CreditKill(db, creatureId, victimGuid, level)
	if type(creatureId) ~= "number" then
		return 0, {}
	end
	return CreditMatching(db, level, victimGuid, function(goal)
		return goal.gameId == creatureId
	end)
end

function ForeverMaker.CreditKillByName(db, name, level)
	local wanted = ForeverMaker.NormalizeCreatureName(name)
	if not wanted then
		return 0, {}
	end
	return CreditMatching(db, level, nil, function(goal)
		return ForeverMaker.NormalizeCreatureName(goal.name) == wanted
	end)
end

function ForeverMaker.OfferKill(db, victimGuid, level, now)
	now = ForeverMaker.KillClock(now)
	prunePending(now)
	if ForeverMaker.HiddenKill(victimGuid) then
		local waiting = table.remove(pendingNames, 1)
		if waiting then
			return ForeverMaker.CreditKillByName(db, waiting.name, level)
		end
		pendingBlows[#pendingBlows + 1] = { time = now }
		return 0, {}
	end
	local creatureId = ForeverMaker.CreatureId(victimGuid)
	if not creatureId then
		return 0, {}
	end
	recentIdentified = now
	table.remove(pendingNames, 1)
	return ForeverMaker.CreditKill(db, creatureId, victimGuid, level)
end

function ForeverMaker.OfferXp(db, text, level, now)
	now = ForeverMaker.KillClock(now)
	prunePending(now)
	local name = ForeverMaker.XpKillName(text)
	if not name then
		return 0, {}
	end
	local blow = pendingBlows[1]
	if blow and (not recentIdentified or blow.time > recentIdentified) then
		table.remove(pendingBlows, 1)
		return ForeverMaker.CreditKillByName(db, name, level)
	end
	if recentIdentified then
		return 0, {}
	end
	pendingNames[#pendingNames + 1] = { time = now, name = name }
	return 0, {}
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

-- Paperdoll slots the Classic Era client can read. Ammo is slot 0 and is added only when that slot exists.
ForeverMaker.GearSlots = {
	{ id = 1, slot = "head" },
	{ id = 2, slot = "neck" },
	{ id = 3, slot = "shoulder" },
	{ id = 4, slot = "shirt" },
	{ id = 5, slot = "chest" },
	{ id = 6, slot = "waist" },
	{ id = 7, slot = "legs" },
	{ id = 8, slot = "feet" },
	{ id = 9, slot = "wrist" },
	{ id = 10, slot = "hands" },
	{ id = 11, slot = "finger1" },
	{ id = 12, slot = "finger2" },
	{ id = 13, slot = "trinket1" },
	{ id = 14, slot = "trinket2" },
	{ id = 15, slot = "back" },
	{ id = 16, slot = "mainhand" },
	{ id = 17, slot = "offhand" },
	{ id = 18, slot = "ranged" },
	{ id = 19, slot = "tabard" },
}

local classIds = {
	[1] = true,
	[2] = true,
	[3] = true,
	[4] = true,
	[5] = true,
	[7] = true,
	[8] = true,
	[9] = true,
	[11] = true,
}

local gearSlotNames = { ammo = true }
for _, slot in ipairs(ForeverMaker.GearSlots) do
	gearSlotNames[slot.slot] = true
end

local function WholeNumber(value)
	return type(value) == "number" and value == math.floor(value) and value >= -2147483647 and value <= 2147483647
end

function ForeverMaker.ValidClassId(classId)
	return WholeNumber(classId) and classIds[classId] == true
end

function ForeverMaker.ParseItemLink(link)
	if type(link) ~= "string" then
		return nil
	end
	local body = string.match(link, "item:([^|]+)")
	if not body then
		return nil
	end
	local fields = {}
	for field in string.gmatch(body .. ":", "([^:]*):") do
		fields[#fields + 1] = field
	end
	local item = tonumber(fields[1])
	local enchant = tonumber(fields[2])
	local suffix = tonumber(fields[7])
	if not WholeNumber(item) or item <= 0 then
		return nil
	end
	if enchant ~= nil and not WholeNumber(enchant) then
		enchant = nil
	end
	if suffix ~= nil and not WholeNumber(suffix) then
		suffix = nil
	end
	return item, enchant, suffix
end

function ForeverMaker.GearRow(slot, item, link)
	if gearSlotNames[slot] ~= true or not WholeNumber(item) or item <= 0 then
		return nil
	end
	local row = { slot = slot, item = item }
	local linkItem, enchant, suffix = ForeverMaker.ParseItemLink(link)
	if linkItem == item then
		if enchant and enchant > 0 then
			row.enchant = enchant
		end
		if suffix and suffix ~= 0 then
			row.suffix = suffix
		end
	end
	return row
end

function ForeverMaker.CopyGear(gear)
	if type(gear) ~= "table" then
		return nil
	end
	local seen = {}
	local out = {}
	for _, row in ipairs(gear) do
		if type(row) == "table" and seen[row.slot] ~= true then
			local copy = ForeverMaker.GearRow(row.slot, row.item, nil)
			if copy then
				if WholeNumber(row.enchant) and row.enchant > 0 then
					copy.enchant = row.enchant
				end
				if WholeNumber(row.suffix) and row.suffix ~= 0 then
					copy.suffix = row.suffix
				end
				seen[row.slot] = true
				out[#out + 1] = copy
			end
		end
	end
	return out
end

function ForeverMaker.CopyCompletion(done)
	if type(done) ~= "table" or type(done.at) ~= "number" or type(done.character) ~= "string" or type(done.level) ~= "number" then
		return nil
	end
	local stamp = {
		at = done.at,
		character = done.character,
		realm = type(done.realm) == "string" and done.realm or "",
		level = done.level,
	}
	if ForeverMaker.ValidClassId(done.classId) then
		stamp.classId = done.classId
	end
	local worn = ForeverMaker.CopyGear(done.gear)
	if worn then
		stamp.gear = worn
	end
	return stamp
end

-- completed is part of the one quest record a later upload sends.
-- at, character, realm, and level travel with the quest id, revision, and goal counts.
-- classId and gear are a snapshot from the moment the last goal filled.
function ForeverMaker.NoteCompletion(quest, when, character, realm, level, classId, gear)
	if type(quest) ~= "table" then
		return
	end
	if not ForeverMaker.GoalsComplete(quest) then
		quest.completed = nil
		return
	end
	if not ForeverMaker.MeetsLevelLimit(quest, level) then
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
	quest.completed = ForeverMaker.CopyCompletion({
		at = when,
		character = character,
		realm = realm,
		level = level,
		classId = classId,
		gear = gear,
	})
end

function ForeverMaker.DropIllegalCompletion(quest, level)
	local constraints = type(quest) == "table" and quest.constraints
	if type(quest) ~= "table" or type(constraints) ~= "table" or #constraints == 0 then
		return false
	end
	local done = quest.completed
	if type(done) == "table" and ForeverMaker.MeetsLevelLimit(quest, done.level) then
		return false
	end
	local stampedPast = type(done) == "table"
	local filledPast = ForeverMaker.GoalsComplete(quest) and type(level) == "number" and not ForeverMaker.MeetsLevelLimit(quest, level)
	if not stampedPast and not filledPast then
		return false
	end
	quest.completed = nil
	if type(quest.goals) == "table" then
		for _, goal in ipairs(quest.goals) do
			if type(goal) == "table" then
				goal.count = 0
			end
		end
	end
	return true
end

function ForeverMaker.EnforceSavedLimits(db, level)
	local dropped = {}
	if type(db) ~= "table" or type(db.quests) ~= "table" then
		return dropped
	end
	for _, quest in pairs(db.quests) do
		if ForeverMaker.DropIllegalCompletion(quest, level) then
			dropped[#dropped + 1] = quest
		end
	end
	return dropped
end

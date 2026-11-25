-- Read a !FM:1! quest string and store it on the character.
-- The paste box is the idea taken from WeakAuras. The string itself is plain text.

ForeverMaker = ForeverMaker or {}

local MAX_GOALS = 20
local MAX_TITLE = 100
local MAX_DESC = 2000
local MAX_NAME = 100
local MAX_QTY = 9999
local MAX_GAME_ID = 2147483647

local UUID = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function Ascii(text)
	for i = 1, #text do
		if string.byte(text, i) > 127 then
			return false
		end
	end
	return true
end

local function TrimEnd(text)
	return (string.gsub(text, "%s+$", ""))
end

local function Lines(text)
	local out = {}
	local start = 1
	while true do
		local found = string.find(text, "\n", start, true)
		if not found then
			out[#out + 1] = string.sub(text, start)
			break
		end
		out[#out + 1] = string.sub(text, start, found - 1)
		start = found + 1
	end
	return out
end

local function WholeNumber(text, maxValue)
	if not text or not string.match(text, "^%d+$") then
		return nil
	end
	local value = tonumber(text)
	if not value or value < 1 or value > maxValue then
		return nil
	end
	return value
end

local function ParseConstraint(rest, expectedPos)
	local posText, kind, comparison, levelText = string.match(rest, "^(%d+)%s+(%a+)%s+(%S+)%s+(%d+)$")
	if not posText then
		return "A constraint line is missing a field."
	end
	local pos = WholeNumber(posText, 1)
	local level = WholeNumber(levelText, 60)
	if pos ~= expectedPos then
		return "Constraint lines must stay in order, starting at 1."
	end
	if kind ~= "level" or comparison ~= "<" or not level or level < 2 then
		return "A level limit must be below a level from 2 to 60."
	end
	return nil, {
		pos = pos,
		kind = kind,
		comparison = comparison,
		level = level,
	}
end

local function ParseGoal(rest, expectedPos)
	local posText, kind, qtyText, idType, gameText, name = string.match(rest, "^(%d+)%s+(%a+)%s+(%d+)%s+(%a+)%s+(%d+)%s+(.+)$")
	if not posText then
		return "A goal line is missing a field."
	end
	name = TrimEnd(name)
	local pos = WholeNumber(posText, MAX_GOALS)
	local quantity = WholeNumber(qtyText, MAX_QTY)
	local gameId = WholeNumber(gameText, MAX_GAME_ID)
	if pos ~= expectedPos then
		return "Goal lines must stay in order, starting at 1."
	end
	if kind ~= "kill" and kind ~= "acquire" and kind ~= "have" and kind ~= "quest" then
		return "A goal must be kill, acquire, have, or quest."
	end
	if not quantity then
		return "A goal quantity must be from 1 to 9999."
	end
	if kind == "have" and quantity ~= 1 then
		return "A have goal is one item."
	end
	if kind == "quest" and quantity ~= 1 then
		return "A quest goal is one quest."
	end
	if kind == "kill" and idType ~= "npc" then
		return "A kill goal uses npc."
	end
	if kind == "acquire" and idType ~= "item" then
		return "An acquire goal uses item."
	end
	if kind == "have" and idType ~= "item" then
		return "A have goal uses item."
	end
	if kind == "quest" and idType ~= "quest" then
		return "A quest goal uses quest."
	end
	if not gameId then
		return "A goal needs a game id."
	end
	if name == "" or #name > MAX_NAME or not Ascii(name) then
		return "A goal name must be 1 to 100 ASCII characters."
	end
	return nil, {
		pos = pos,
		kind = kind,
		quantity = quantity,
		idType = idType,
		gameId = gameId,
		name = name,
	}
end

function ForeverMaker.Parse(text)
	if type(text) ~= "string" then
		return nil, "Paste a quest string."
	end
	text = string.gsub(text, "\r\n", "\n")
	text = string.gsub(text, "\r", "\n")
	text = string.gsub(text, "^\239\187\191", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		return nil, "Paste a quest string."
	end

	local lines = Lines(text)
	local version = string.match(lines[1], "^!FM:(%d+)!$")
	if not version then
		return nil, "That string is not a ForeverMaker quest."
	end
	if version ~= "1" then
		return nil, "Update the addon."
	end

	local fields = {}
	local goals = {}
	local constraints = {}
	local sawGoal = false
	local sawConstraint = false
	for i = 2, #lines do
		local line = lines[i]
		if line == "" then
			return nil, "That string has a blank line."
		end
		local key, rest = string.match(line, "^(%S+)%s*(.*)$")
		if key == "goal" then
			if sawConstraint then
				return nil, "Goals come before constraints."
			end
			sawGoal = true
			local err, goal = ParseGoal(rest, #goals + 1)
			if err then
				return nil, err
			end
			goals[#goals + 1] = goal
		elseif key == "constraint" then
			if not sawGoal then
				return nil, "Constraints come after the goals."
			end
			sawConstraint = true
			local err, limit = ParseConstraint(rest, #constraints + 1)
			if err then
				return nil, err
			end
			constraints[#constraints + 1] = limit
		else
			if sawGoal or sawConstraint then
				return nil, "That string has a line after the goals."
			end
			if key ~= "id" and key ~= "rev" and key ~= "title" and key ~= "desc" then
				return nil, "That string has a line the addon does not know."
			end
			if fields[key] ~= nil then
				return nil, "That string repeats " .. key .. "."
			end
			fields[key] = rest
		end
	end

	if fields.id == nil or fields.rev == nil or fields.title == nil or fields.desc == nil then
		return nil, "That string is missing id, rev, title, or desc."
	end
	if not string.match(fields.id, UUID) and not string.match(fields.id, "^[%w_%-][%w_%-][%w_%-][%w_%-][%w_%-][%w_%-][%w_%-][%w_%-]$") then
		return nil, "That quest id is not one this addon can store."
	end
	local rev = WholeNumber(fields.rev, 1000000)
	if not rev then
		return nil, "The revision must be a whole number starting at 1."
	end
	local title = TrimEnd(fields.title)
	if title == "" or #title > MAX_TITLE or not Ascii(title) then
		return nil, "The title must be 1 to 100 ASCII characters."
	end
	local desc = TrimEnd(fields.desc)
	if #desc > MAX_DESC or not Ascii(desc) then
		return nil, "The description must be at most 2000 ASCII characters."
	end
	if #goals < 1 then
		return nil, "A quest needs at least one goal."
	end
	if #goals > MAX_GOALS then
		return nil, "A quest can have at most 20 goals."
	end

	return {
		id = fields.id,
		rev = rev,
		title = title,
		desc = desc,
		goals = goals,
		constraints = constraints,
	}
end

local function CopyGoals(goals, previous, keepCounts)
	local out = {}
	for i, goal in ipairs(goals) do
		local count = 0
		local old = keepCounts and previous and previous[i]
		if old and old.kind == goal.kind and old.gameId == goal.gameId and type(old.count) == "number" then
			count = old.count
			if count < 0 then
				count = 0
			end
			if count > goal.quantity then
				count = goal.quantity
			end
		end
		out[i] = {
			pos = goal.pos,
			kind = goal.kind,
			quantity = goal.quantity,
			idType = goal.idType,
			gameId = goal.gameId,
			name = goal.name,
			count = count,
		}
	end
	return out
end

function ForeverMaker.LevelLimitText(quest)
	local constraints = type(quest) == "table" and quest.constraints
	if type(constraints) ~= "table" then
		return nil
	end
	for _, limit in ipairs(constraints) do
		if type(limit) == "table" and limit.kind == "level" and limit.comparison == "<" and type(limit.level) == "number" then
			return "Level < " .. limit.level
		end
	end
	return nil
end

function ForeverMaker.Apply(db, quest)
	db.quests = db.quests or {}
	db.order = db.order or {}
	local existing = db.quests[quest.id]
	if existing and type(existing.rev) == "number" and quest.rev < existing.rev then
		return "older"
	end

	local keepCounts = existing and existing.rev == quest.rev
	local stored = {
		id = quest.id,
		rev = quest.rev,
		title = quest.title,
		desc = quest.desc,
		goals = CopyGoals(quest.goals, existing and existing.goals, keepCounts),
		constraints = quest.constraints,
	}
	local done = keepCounts and existing and existing.completed
	local stamp = ForeverMaker.CopyCompletion(done)
	if stamp and ForeverMaker.GoalsComplete(stored) then
		stored.completed = stamp
	end
	local isNew = existing == nil
	db.quests[quest.id] = stored
	if isNew then
		db.order[#db.order + 1] = quest.id
	end
	if existing and quest.rev > existing.rev then
		return "replaced"
	end
	if existing then
		return "kept"
	end
	return "saved"
end

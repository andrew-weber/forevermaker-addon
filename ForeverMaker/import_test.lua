-- lua5.1 addon/ForeverMaker/import_test.lua
local root = string.match(arg[0], "^(.*)/") or "."
ForeverMaker = {}
dofile(root .. "/Import.lua")
dofile(root .. "/Progress.lua")

local failed = 0

local function Check(name, ok)
	if ok then
		print("ok " .. name)
	else
		failed = failed + 1
		print("FAIL " .. name)
	end
end

local small = [[!FM:1!
id 00000000-0000-4000-8000-000000000001
rev 1
title Small Game
desc
goal 1 kill 1 npc 708 Small Crag Boar
]]

local both = [[!FM:1!
id 00000000-0000-4000-8000-000000000002
rev 1
title Boar meat
desc Bring back meat from the boars.
goal 1 kill 5 npc 708 Small Crag Boar
goal 2 acquire 3 item 769 Chunk of Boar Meat
]]

local quest, err = ForeverMaker.Parse(small)
Check("parse small", quest and quest.title == "Small Game" and quest.desc == "" and quest.goals[1].gameId == 708 and not err)

quest, err = ForeverMaker.Parse(both)
Check("parse both", quest and #quest.goals == 2 and quest.goals[2].kind == "acquire" and quest.goals[2].name == "Chunk of Boar Meat")

local _, bad = ForeverMaker.Parse("!FM:2!\nid 00000000-0000-4000-8000-000000000001\nrev 1\ntitle A\ndesc\ngoal 1 kill 1 npc 1 Boar\n")
Check("newer string", bad == "Update the addon.")

_, bad = ForeverMaker.Parse("!FM:1!\nid 00000000-0000-4000-8000-000000000001\nrev 1\ntitle A\ndesc\ngoal 1 kill 1 item 1 Boar\n")
Check("kill uses npc", bad == "A kill goal uses npc.")

_, bad = ForeverMaker.Parse("!FM:1!\nid nope\nrev 1\ntitle A\ndesc\ngoal 1 kill 1 npc 1 Boar\n")
Check("bad id", bad == "That quest id is not one this addon can store.")

_, bad = ForeverMaker.Parse("!FM:1!\nid 00000000-0000-4000-8000-000000000001\nrev 1\ntitle A\ndesc\ngoal 2 kill 1 npc 1 Boar\n")
Check("goal order", bad == "Goal lines must stay in order, starting at 1.")

local db = { quests = {}, order = {} }
local first = ForeverMaker.Parse(small)
Check("save new", ForeverMaker.Apply(db, first) == "saved" and db.quests[first.id].goals[1].count == 0)

first.goals[1].name = "Small Crag Boar"
db.quests[first.id].goals[1].count = 1
db.quests[first.id].completed = { at = 1000, character = "Daklulim", realm = "Westfall", level = 4 }
local again = ForeverMaker.Parse(small)
Check("same rev keeps count", ForeverMaker.Apply(db, again) == "kept" and db.quests[first.id].goals[1].count == 1 and db.quests[first.id].completed.at == 1000)

local higher = ForeverMaker.Parse(string.gsub(small, "rev 1", "rev 2"))
Check("higher rev clears", ForeverMaker.Apply(db, higher) == "replaced" and db.quests[first.id].goals[1].count == 0 and db.quests[first.id].rev == 2 and db.quests[first.id].completed == nil)

local lower = ForeverMaker.Parse(small)
Check("older refused", ForeverMaker.Apply(db, lower) == "older" and db.quests[first.id].rev == 2)

Check("creature id", ForeverMaker.CreatureId("Creature-0-5165-1-49-3098-000061FF60") == 3098)
Check("player guid is not a creature", ForeverMaker.CreatureId("Player-5149-04E9ED41") == nil)

local creditDb = db
local id = first.id
creditDb.quests[id].goals[1].count = 0
creditDb.quests[id].goals[1].quantity = 1
creditDb.quests[id].goals[1].gameId = 3098
local guid = "Creature-0-5165-1-49-3098-000061FF60"
Check("credit once", ForeverMaker.CreditKill(creditDb, 3098, guid) == 1 and creditDb.quests[id].goals[1].count == 1)
Check("same death ignored", ForeverMaker.CreditKill(creditDb, 3098, guid) == 0 and creditDb.quests[id].goals[1].count == 1)
Check("full goal stays full", ForeverMaker.CreditKill(creditDb, 3098, guid .. "b") == 0)

local finished = creditDb.quests[id]
ForeverMaker.NoteCompletion(finished, 1700000000, "Daklulim", "Westfall", 4)
Check("completion stamp", finished.completed.at == 1700000000 and finished.completed.character == "Daklulim" and finished.completed.realm == "Westfall" and finished.completed.level == 4)
ForeverMaker.NoteCompletion(finished, 1800000000, "Someone", "Other", 20)
Check("first completion stays", finished.completed.at == 1700000000 and finished.completed.character == "Daklulim")
finished.goals[1].count = 0
ForeverMaker.NoteCompletion(finished, 1800000000, "Daklulim", "Westfall", 4)
Check("open quest drops completion", finished.completed == nil)

if failed > 0 then
	os.exit(1)
end
print("all passed")

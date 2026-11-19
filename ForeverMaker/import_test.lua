-- lua5.1 addon/ForeverMaker/import_test.lua
local root = string.match(arg[0], "^(.*)/") or "."
ForeverMaker = {}
dofile(root .. "/Import.lua")
dofile(root .. "/Progress.lua")
dofile(root .. "/Inbox.lua")

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

local public = "!FM:1!\nid k3J8aQ_z\nrev 1\ntitle Boar trouble\ndesc Clear the field.\ngoal 1 kill 10 npc 708 Mangy Boar"
quest, err = ForeverMaker.Parse(public)
Check("public id", quest and quest.id == "k3J8aQ_z" and quest.title == "Boar trouble" and quest.desc == "Clear the field." and quest.goals[1].name == "Mangy Boar" and quest.goals[1].gameId == 708 and not err)

local limited = public .. "\nconstraint 1 level < 5"
quest, err = ForeverMaker.Parse(limited)
Check("level limit", quest and quest.constraints[1].kind == "level" and quest.constraints[1].comparison == "<" and quest.constraints[1].level == 5 and ForeverMaker.LevelLimitText(quest) == "Level < 5" and not err)

_, bad = ForeverMaker.Parse(public .. "\nconstraint 1 level < 1")
Check("level one", bad == "A level limit must be below a level from 2 to 60.")

_, bad = ForeverMaker.Parse(public .. "\nconstraint 1 timer < 10")
Check("timer limit", bad == "A level limit must be below a level from 2 to 60.")

_, bad = ForeverMaker.Parse("!FM:1!\nid 00000000-0000-4000-8000-000000000001\nrev 1\ntitle A\ndesc\ngoal 2 kill 1 npc 1 Boar\n")
Check("goal order", bad == "Goal lines must stay in order, starting at 1.")

local db = { quests = {}, order = {} }
local first = ForeverMaker.Parse(small)
Check("save new", ForeverMaker.Apply(db, first) == "saved" and db.quests[first.id].goals[1].count == 0)

first.goals[1].name = "Small Crag Boar"
db.quests[first.id].goals[1].count = 1
db.quests[first.id].completed = { at = 1000, character = "Daklulim", realm = "Westfall", level = 4 }
local again = ForeverMaker.Parse(small)
Check("same rev keeps count", ForeverMaker.Apply(db, again) == "kept" and db.quests[first.id].goals[1].count == 1 and db.quests[first.id].completed.at == 1000 and db.quests[first.id].completed.classId == nil and db.quests[first.id].completed.gear == nil)

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

local underTwo = ForeverMaker.Parse("!FM:1!\nid k3J8aQ_z\nrev 1\ntitle Trogg\ndesc\ngoal 1 kill 1 npc 708 Rockjaw Trogg\nconstraint 1 level < 2")
Check("limit applied", ForeverMaker.Apply(creditDb, underTwo) == "saved")
local limitedId = underTwo.id
Check("level two misses", ForeverMaker.CreditKill(creditDb, 708, guid .. "c", 2) == 0 and creditDb.quests[limitedId].goals[1].count == 0)
Check("level one counts", ForeverMaker.CreditKill(creditDb, 708, guid .. "d", 1) == 1 and creditDb.quests[limitedId].goals[1].count == 1)
ForeverMaker.NoteCompletion(creditDb.quests[limitedId], 1700000000, "Daklulim", "Westfall", 2)
Check("finish past the limit is refused", creditDb.quests[limitedId].completed == nil)
ForeverMaker.NoteCompletion(creditDb.quests[limitedId], 1700000000, "Daklulim", "Westfall", 1)
Check("finish under the limit is kept", creditDb.quests[limitedId].completed.level == 1)
Check("later level keeps a legal finish", not ForeverMaker.DropIllegalCompletion(creditDb.quests[limitedId], 2) and creditDb.quests[limitedId].completed.level == 1)
creditDb.quests[limitedId].completed.level = 2
Check("saved finish past the limit is cleared", ForeverMaker.DropIllegalCompletion(creditDb.quests[limitedId], 2) and creditDb.quests[limitedId].completed == nil and creditDb.quests[limitedId].goals[1].count == 0)

local finished = creditDb.quests[id]
ForeverMaker.NoteCompletion(finished, 1700000000, "Daklulim", "Westfall", 4)
Check("completion stamp", finished.completed.at == 1700000000 and finished.completed.character == "Daklulim" and finished.completed.realm == "Westfall" and finished.completed.level == 4)
ForeverMaker.NoteCompletion(finished, 1800000000, "Someone", "Other", 20)
Check("first completion stays", finished.completed.at == 1700000000 and finished.completed.character == "Daklulim")
finished.goals[1].count = 0
ForeverMaker.NoteCompletion(finished, 1800000000, "Daklulim", "Westfall", 4)
Check("open quest drops completion", finished.completed == nil)

local itemId, enchantId, suffixId = ForeverMaker.ParseItemLink("|cff0070dd|Hitem:19364:2564:::::::60:::::::|h[Ashkandi]|h|r")
Check("link enchant", itemId == 19364 and enchantId == 2564 and suffixId == nil)
itemId, enchantId, suffixId = ForeverMaker.ParseItemLink("|cff1eff00|Hitem:7728:0:0:0:0:0:-12:0:20|h[Beguiler Robes]|h|r")
Check("link suffix", itemId == 7728 and enchantId == 0 and suffixId == -12)
Check("link missing", ForeverMaker.ParseItemLink("not an item") == nil)

local gearText = string.gsub(small, "000000000001", "000000000009")
local gearParsed = ForeverMaker.Parse(gearText)
Check("gear quest saved", ForeverMaker.Apply(creditDb, gearParsed) == "saved")
local storedGear = creditDb.quests[gearParsed.id]
storedGear.goals[1].count = 1
ForeverMaker.NoteCompletion(storedGear, 1700000000, "Daklulim", "Westfall", 4, 3, {
	ForeverMaker.GearRow("mainhand", 19364, "|cff0070dd|Hitem:19364:2564:::::::60:::::::|h[Ashkandi]|h|r"),
	ForeverMaker.GearRow("wrist", 7728, "|cff1eff00|Hitem:7728:0:0:0:0:0:-12:0:20|h[Beguiler Robes]|h|r"),
	ForeverMaker.GearRow("chest", 2105, "|cffffffff|Hitem:999::::::::1:::::::|h[Wrong]|h|r"),
	{ slot = "boots", item = 1 },
	{ slot = "head", item = 1411, enchant = 0, suffix = 0 },
	{ slot = "head", item = 22 },
})
local gear = storedGear.completed.gear
Check("class and gear saved", storedGear.completed.classId == 3 and #gear == 4 and gear[1].slot == "mainhand" and gear[1].item == 19364 and gear[1].enchant == 2564 and gear[1].suffix == nil and gear[2].slot == "wrist" and gear[2].suffix == -12 and gear[2].enchant == nil and gear[3].slot == "chest" and gear[3].item == 2105 and gear[3].enchant == nil and gear[3].suffix == nil and gear[4].slot == "head" and gear[4].item == 1411 and gear[4].enchant == nil and gear[4].suffix == nil)
ForeverMaker.NoteCompletion(storedGear, 1800000000, "Someone", "Other", 20, 8, {})
Check("first class and gear stay", storedGear.completed.at == 1700000000 and storedGear.completed.classId == 3 and storedGear.completed.gear[1].enchant == 2564)
Check("same rev keeps class and gear", ForeverMaker.Apply(creditDb, ForeverMaker.Parse(gearText)) == "kept" and creditDb.quests[gearParsed.id].completed.classId == 3 and creditDb.quests[gearParsed.id].completed.gear[2].suffix == -12 and #creditDb.quests[gearParsed.id].completed.gear == 4)

local bare = ForeverMaker.Parse(string.gsub(small, "000000000001", "000000000008"))
Check("bare quest saved", ForeverMaker.Apply(creditDb, bare) == "saved")
local bareQuest = creditDb.quests[bare.id]
bareQuest.goals[1].count = 1
ForeverMaker.NoteCompletion(bareQuest, 1700000000, "Daklulim", "Westfall", 4, 6, {})
Check("unknown class omitted", bareQuest.completed.classId == nil and bareQuest.completed.level == 4 and type(bareQuest.completed.gear) == "table" and #bareQuest.completed.gear == 0)

local rows = ForeverMaker.CopyGear({
	{ slot = "neck", item = 1200, enchant = 1.5 },
	{ slot = "ammo", item = 2515 },
})
Check("bad enchant dropped", #rows == 2 and rows[1].slot == "neck" and rows[1].enchant == nil and rows[2].slot == "ammo" and rows[2].item == 2515)

local devout = ForeverMaker.Parse("!FM:1!\nid devout01\nrev 1\ntitle Devout\ndesc\ngoal 1 have 1 item 16694 Devout Crown\ngoal 2 have 1 item 16693 Devout Bracers\ngoal 3 kill 1 npc 708 Mangy Boar")
local badHave, badHaveErr = ForeverMaker.Parse("!FM:1!\nid devout01\nrev 1\ntitle Devout\ndesc\ngoal 1 have 2 item 16694 Devout Crown")
Check("parse have", devout and devout.goals[1].kind == "have" and devout.goals[1].quantity == 1 and devout.goals[1].idType == "item" and devout.goals[1].gameId == 16694 and badHave == nil and badHaveErr == "A have goal is one item.")
local heldDb = { quests = {}, order = {} }
Check("have quest saved", ForeverMaker.Apply(heldDb, devout) == "saved" and heldDb.quests[devout.id].goals[1].count == 0)
local owned = { [16694] = true }
Check("owned piece is complete", ForeverMaker.RefreshHeld(heldDb, function(itemId) return owned[itemId] == true end) and heldDb.quests[devout.id].goals[1].count == 1 and heldDb.quests[devout.id].goals[2].count == 0 and heldDb.quests[devout.id].goals[3].count == 0)
owned[16693] = true
Check("second piece completes", ForeverMaker.RefreshHeld(heldDb, function(itemId) return owned[itemId] == true end) and heldDb.quests[devout.id].goals[2].count == 1)
heldDb.quests[devout.id].goals[3].count = 1
heldDb.quests[devout.id].completed = { at = 10, character = "Daklulim", realm = "Westfall", level = 1 }
owned[16694] = nil
Check("missing piece clears the finish", ForeverMaker.RefreshHeld(heldDb, function(itemId) return owned[itemId] == true end) and heldDb.quests[devout.id].goals[1].count == 0 and heldDb.quests[devout.id].completed == nil)

ForeverMaker.ResetSeen()
local namedText = "!FM:1!\nid g0rg3rQz\nrev 1\ntitle Gorgers\ndesc\ngoal 1 kill 3 npc 12345 Mindless Gorger"
local named = ForeverMaker.Parse(namedText)
local namedDb = { quests = {}, order = {} }
Check("named quest saved", ForeverMaker.Apply(namedDb, named) == "saved")
local gorger = namedDb.quests[named.id].goals[1]
local xpLine = "Mindless Gorger dies, you gain 40 experience."
Check("xp names the creature", ForeverMaker.XpKillName(xpLine) == "Mindless Gorger")
Check("rested xp still names it", ForeverMaker.XpKillName("Mindless Gorger dies, you gain 1,025 experience. (+60 exp Rested bonus)") == "Mindless Gorger")
Check("quest xp is not a kill", ForeverMaker.XpKillName("You gain 50 experience.") == nil)
Check("xp alone does not count", ForeverMaker.OfferXp(namedDb, xpLine, 40, 10) == 0 and gorger.count == 0)
Check("hidden blow takes the waiting name", ForeverMaker.OfferKill(namedDb, nil, 40, 10) == 1 and gorger.count == 1)
Check("hidden blow waits for a name", ForeverMaker.OfferKill(namedDb, nil, 40, 11) == 0 and gorger.count == 1)
Check("xp fills the waiting blow", ForeverMaker.OfferXp(namedDb, "mindless gorger dies, you gain 40 experience.", 40, 12) == 1 and gorger.count == 2)
Check("xp without a blow does not count", ForeverMaker.OfferXp(namedDb, xpLine, 40, 20) == 0 and gorger.count == 2)
Check("later xp misses the expired blow", ForeverMaker.OfferKill(namedDb, nil, 40, 30) == 0 and ForeverMaker.OfferXp(namedDb, xpLine, 40, 34) == 0 and gorger.count == 2)
local boarGuid = "Creature-0-5165-1-49-3098-000061FF60"
gorger.gameId = 3098
gorger.name = "Mottled Boar"
Check("readable kill counts by id", ForeverMaker.OfferKill(namedDb, boarGuid, 40, 40) == 1 and gorger.count == 3)
Check("xp after a readable kill does not count again", ForeverMaker.OfferXp(namedDb, "Mottled Boar dies, you gain 25 experience.", 40, 41) == 0 and gorger.count == 3)
local other = "Creature-0-5165-1-49-3099-000061FF61"
Check("another name does not match", ForeverMaker.OfferKill(namedDb, nil, 40, 50) == 0 and ForeverMaker.OfferXp(namedDb, "Risen Sentry dies, you gain 99 experience.", 40, 51) == 0 and gorger.count == 3)
local limitDb = { quests = {}, order = {} }
local limitedNamed = ForeverMaker.Parse("!FM:1!\nid tr0ggLim\nrev 1\ntitle Trogg\ndesc\ngoal 1 kill 1 npc 708 Rockjaw Trogg\nconstraint 1 level < 2")
Check("limited named quest saved", ForeverMaker.Apply(limitDb, limitedNamed) == "saved")
local trogg = limitDb.quests[limitedNamed.id].goals[1]
Check("name waits for the blow", ForeverMaker.OfferXp(limitDb, "Rockjaw Trogg dies, you gain 44 experience.", 2, 60) == 0 and trogg.count == 0)
local hits, blocked = ForeverMaker.OfferKill(limitDb, nil, 2, 60)
Check("level blocks the named kill", hits == 0 and trogg.count == 0 and blocked[1] == limitDb.quests[limitedNamed.id])
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
Check("client xp pattern", ForeverMaker.XpKillName("Mindless Gorger dies, you gain 40 experience.") == "Mindless Gorger")
COMBATLOG_XPGAIN_FIRSTPERSON = nil

dofile(root .. "/InboxData.lua")
local inboxDb = { quests = {}, order = {} }
ForeverMakerInbox = {
	{ game = "classic", text = small },
	{ game = "forever", text = public },
}
Check("classic inbox", ForeverMaker.ApplyInbox(inboxDb, "classic") == 1 and inboxDb.quests[first.id] and not inboxDb.quests["k3J8aQ_z"])
Check("forever inbox", ForeverMaker.ApplyInbox(inboxDb, "forever") == 1 and inboxDb.quests["k3J8aQ_z"])
inboxDb.quests[first.id].goals[1].count = 1
Check("same inbox keeps progress", ForeverMaker.ApplyInbox(inboxDb, "classic") == 0 and inboxDb.quests[first.id].goals[1].count == 1)

if failed > 0 then
	os.exit(1)
end
print("all passed")

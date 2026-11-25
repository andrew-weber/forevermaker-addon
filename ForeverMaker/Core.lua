-- Saved progress for this character, the slash command, and the killing-blow event.

ForeverMaker = ForeverMaker or {}

function ForeverMaker.EnsureDB()
	if type(ForeverMakerDB) ~= "table" then
		ForeverMakerDB = {}
	end
	if type(ForeverMakerDB.quests) ~= "table" then
		ForeverMakerDB.quests = {}
	end
	if type(ForeverMakerDB.order) ~= "table" then
		ForeverMakerDB.order = {}
	end

	local known = {}
	local order = {}
	for _, id in ipairs(ForeverMakerDB.order) do
		if type(id) == "string" and ForeverMakerDB.quests[id] and not known[id] then
			known[id] = true
			order[#order + 1] = id
		end
	end
	for id in pairs(ForeverMakerDB.quests) do
		if not known[id] then
			known[id] = true
			order[#order + 1] = id
		end
	end
	ForeverMakerDB.order = order
	ForeverMaker.ReportClearedLimits(ForeverMakerDB)
end

function ForeverMaker.ReportClearedLimits(db)
	local level = nil
	if UnitLevel then
		level = UnitLevel("player")
	end
	local dropped = ForeverMaker.EnforceSavedLimits(db, level)
	if not DEFAULT_CHAT_FRAME then
		return
	end
	for _, quest in ipairs(dropped) do
		local label = ForeverMaker.LevelLimitText(quest) or "its level limit"
		local title = type(quest.title) == "string" and quest.title or "A quest"
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ForeverMaker:|r " .. title .. " was cleared. Finish it while " .. label .. ".")
	end
end

function ForeverMaker.ThisCharacter()
	local name, realm = UnitName("player")
	if type(realm) ~= "string" or realm == "" then
		realm = GetRealmName()
	end
	return GetServerTime(), name, realm, UnitLevel("player")
end

function ForeverMaker.PlayerClassId()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local _, _, classId = UnitClass("player")
	if ForeverMaker.ValidClassId(classId) then
		return classId
	end
	return nil
end

-- Worn gear is the paperdoll at the finish. Each row is slot, item id, and enchant or suffix from the item link.
-- Empty slots, bags, stats, and gems are left out. Ammo is included only when this client still has AmmoSlot 0.
function ForeverMaker.PlayerGear()
	local rows = {}
	local function add(slotId, name)
		if type(GetInventoryItemID) ~= "function" then
			return
		end
		local item = GetInventoryItemID("player", slotId)
		if type(item) ~= "number" or item <= 0 then
			return
		end
		local link = nil
		if type(GetInventoryItemLink) == "function" then
			link = GetInventoryItemLink("player", slotId)
		end
		local row = ForeverMaker.GearRow(name, item, link)
		if row then
			rows[#rows + 1] = row
		end
	end
	if type(GetInventorySlotInfo) == "function" then
		local ok, ammo = pcall(GetInventorySlotInfo, "AmmoSlot")
		if ok and ammo == 0 then
			add(0, "ammo")
		end
	end
	for _, slot in ipairs(ForeverMaker.GearSlots) do
		add(slot.id, slot.slot)
	end
	return rows
end

function ForeverMaker.ApplyKillCredit(hits, blocked)
	if hits <= 0 then
		if type(blocked) == "table" and DEFAULT_CHAT_FRAME then
			for _, quest in ipairs(blocked) do
				local label = ForeverMaker.LevelLimitText(quest) or "its level limit"
				local title = type(quest.title) == "string" and quest.title or "That quest"
				DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ForeverMaker:|r " .. title .. " did not count that kill. It requires " .. label .. ".")
			end
		end
		return
	end
	local when, name, realm, level = ForeverMaker.ThisCharacter()
	local classId = ForeverMaker.PlayerClassId()
	local gear = ForeverMaker.PlayerGear()
	for _, quest in pairs(ForeverMakerDB.quests) do
		ForeverMaker.NoteCompletion(quest, when, name, realm, level, classId, gear)
	end
	if ForeverMaker.RefreshLog then
		ForeverMaker.RefreshLog()
	end
end

function ForeverMaker.OnPartyKill(_, victimGuid)
	ForeverMaker.EnsureDB()
	local _, _, _, level = ForeverMaker.ThisCharacter()
	local hits, blocked = ForeverMaker.OfferKill(ForeverMakerDB, victimGuid, level)
	ForeverMaker.ApplyKillCredit(hits, blocked)
end

function ForeverMaker.OnXpGain(text)
	ForeverMaker.EnsureDB()
	local _, _, _, level = ForeverMaker.ThisCharacter()
	local hits, blocked = ForeverMaker.OfferXp(ForeverMakerDB, text, level)
	ForeverMaker.ApplyKillCredit(hits, blocked)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PARTY_KILL")
events:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= "ForeverMaker" then
			return
		end
		ForeverMaker.EnsureDB()
		if ForeverMaker.ApplyInbox then
			ForeverMaker.ApplyInbox(ForeverMakerDB, ForeverMaker.ClientGame and ForeverMaker.ClientGame())
		end
		ForeverMaker.SyncHeld(ForeverMakerDB)
		ForeverMaker.BuildFrames()
		ForeverMaker.RefreshLog()
	elseif event == "PARTY_KILL" then
		ForeverMaker.OnPartyKill(...)
	elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
		ForeverMaker.OnXpGain(...)
	elseif event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "QUEST_TURNED_IN" then
		ForeverMaker.EnsureDB()
		if ForeverMaker.SyncHeld(ForeverMakerDB) and ForeverMaker.RefreshLog then
			ForeverMaker.RefreshLog()
		end
	end
end)

SLASH_FOREVERMAKER1 = "/fm"
SLASH_FOREVERMAKER2 = "/forevermaker"
SlashCmdList.FOREVERMAKER = function()
	ForeverMaker.EnsureDB()
	ForeverMaker.SyncHeld(ForeverMakerDB)
	ForeverMaker.BuildFrames()
	ForeverMaker.ToggleLog()
end

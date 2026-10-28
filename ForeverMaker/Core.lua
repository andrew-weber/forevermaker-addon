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

function ForeverMaker.OnPartyKill(_, victimGuid)
	ForeverMaker.EnsureDB()
	local creatureId = ForeverMaker.CreatureId(victimGuid)
	local _, _, _, level = ForeverMaker.ThisCharacter()
	local hits, blocked = ForeverMaker.CreditKill(ForeverMakerDB, creatureId, victimGuid, level)
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
	for _, quest in pairs(ForeverMakerDB.quests) do
		ForeverMaker.NoteCompletion(quest, when, name, realm, level)
	end
	if ForeverMaker.RefreshLog then
		ForeverMaker.RefreshLog()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PARTY_KILL")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= "ForeverMaker" then
			return
		end
		ForeverMaker.EnsureDB()
		ForeverMaker.BuildFrames()
		ForeverMaker.RefreshLog()
	elseif event == "PARTY_KILL" then
		ForeverMaker.OnPartyKill(...)
	end
end)

SLASH_FOREVERMAKER1 = "/fm"
SLASH_FOREVERMAKER2 = "/forevermaker"
SlashCmdList.FOREVERMAKER = function()
	ForeverMaker.EnsureDB()
	ForeverMaker.BuildFrames()
	ForeverMaker.ToggleLog()
end

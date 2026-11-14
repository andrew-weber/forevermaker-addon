-- Our quest log. Leatrix only resizes Blizzard's QuestLogFrame, so this window is drawn here.
-- Left list, right page, goal counts, and the story. Import, Remove, and Close.

ForeverMaker = ForeverMaker or {}

local log
local importFrame
local listButtons = {}
local goalLines = {}
local ROW_H = 16
local LIST_W = 220
local LIST_H = 364

local function OpaqueFill(frame, red, green, blue)
	frame:SetBackdropColor(red, green, blue, 1)
	frame:SetBackdropBorderColor(1, 1, 1, 1)
	local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetPoint("TOPLEFT", 12, -12)
	fill:SetPoint("BOTTOMRIGHT", -12, 12)
	fill:SetColorTexture(red, green, blue, 1)
	return fill
end

local RESULT_TEXT = {
	saved = "Quest saved.",
	kept = "Quest saved. Progress kept.",
	replaced = "This quest changed. Progress was cleared.",
}

local function Note(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ForeverMaker:|r " .. text)
	end
end

local function AllDone(quest)
	return ForeverMaker.GoalsComplete(quest)
end

local function CompletionText(completed)
	if type(completed) ~= "table" or type(completed.character) ~= "string" or type(completed.level) ~= "number" or type(completed.at) ~= "number" then
		return nil
	end
	local who = completed.character
	if type(completed.realm) == "string" and completed.realm ~= "" then
		who = who .. " " .. completed.realm
	end
	local whenText = completed.at
	if date then
		whenText = date("%B %d, %Y, %I:%M %p", completed.at)
	end
	return "Completed by " .. who .. " at level " .. completed.level .. ".\n" .. whenText
end

local function SelectedQuest()
	local id = ForeverMaker.selectedId
	if id and ForeverMakerDB and ForeverMakerDB.quests and ForeverMakerDB.quests[id] then
		return ForeverMakerDB.quests[id]
	end
	return nil
end

local function TextHeight(fs, text)
	local height = fs:GetStringHeight()
	if height and height >= 14 then
		return height
	end
	local perLine = 40
	local lines = math.ceil((text and #text or 0) / perLine)
	if lines < 1 then
		lines = 1
	end
	return lines * 14
end

local function Place(fs, anchor, y)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", anchor, "TOPLEFT", 12, y)
	fs:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -28, y)
end

function ForeverMaker.RefreshLog()
	if not log then
		return
	end
	ForeverMaker.EnsureDB()
	local order = ForeverMakerDB.order
	if ForeverMaker.selectedId == nil and order[1] then
		ForeverMaker.selectedId = order[1]
	end
	if ForeverMaker.selectedId and not ForeverMakerDB.quests[ForeverMaker.selectedId] then
		ForeverMaker.selectedId = order[1]
	end

	local listChild = log.listChild
	listChild:SetHeight(math.max(#order * ROW_H, 1))
	for i, id in ipairs(order) do
		local button = listButtons[i]
		if not button then
			-- Forever has no Classic QuestLogTitleButtonTemplate. Inheriting it errors
			-- after Save, so the quest is stored and the list stays at zero.
			button = CreateFrame("Button", nil, listChild)
			button:SetSize(LIST_W - 8, ROW_H)
			button:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -((i - 1) * ROW_H))
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
			local bar = button:GetHighlightTexture()
			if bar then
				bar:SetBlendMode("ADD")
				bar:SetVertexColor(1, 0.82, 0)
			end
			button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			button.label:SetPoint("LEFT", 4, 0)
			button.label:SetPoint("RIGHT", -20, 0)
			button.label:SetJustifyH("LEFT")
			button.check = button:CreateTexture(nil, "OVERLAY")
			button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
			button.check:SetSize(16, 16)
			button.check:SetPoint("RIGHT", -2, 0)
			button.check:Hide()
			button:SetScript("OnClick", function(self)
				ForeverMaker.selectedId = self.questId
				ForeverMaker.RefreshLog()
			end)
			listButtons[i] = button
		end
		local quest = ForeverMakerDB.quests[id]
		button.questId = id
		local title = quest.title or ""
		local limitText = ForeverMaker.LevelLimitText(quest)
		local past = limitText and UnitLevel and not ForeverMaker.MeetsLevelLimit(quest, UnitLevel("player"))
		if past then
			title = "|cffff4040Past " .. limitText .. "|r  " .. title
		elseif limitText then
			title = "|cffffd100" .. limitText .. "|r  " .. title
		end
		button.label:SetText(title)
		if id == ForeverMaker.selectedId then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
		if button.check then
			button.check:SetShown(AllDone(quest))
		end
		button:Show()
	end
	for i = #order + 1, #listButtons do
		listButtons[i]:Hide()
	end
	log.count:SetText("Quests: " .. #order)

	local quest = SelectedQuest()
	local showPage = quest ~= nil
	log.empty:SetShown(not showPage)
	log.detail:SetShown(showPage)
	log.removeButton:SetEnabled(showPage)
	if not quest then
		return
	end

	local child = log.detailChild
	log.title:SetText(quest.title or "")
	local y = -12 - TextHeight(log.title, quest.title) - 10
	local limitText = ForeverMaker.LevelLimitText(quest)
	if limitText then
		log.constraintHeader:Show()
		log.constraintNote:Show()
		log.constraintLine:Show()
		local past = UnitLevel and not ForeverMaker.MeetsLevelLimit(quest, UnitLevel("player"))
		if past then
			log.constraintLine:SetText("|cffff4040" .. limitText .. " — you are past this limit|r")
		else
			log.constraintLine:SetText("|cffffd100" .. limitText .. "|r")
		end
		Place(log.constraintHeader, child, y)
		y = y - TextHeight(log.constraintHeader, "Constraints") - 4
		Place(log.constraintNote, child, y)
		y = y - TextHeight(log.constraintNote, "Keep within these limits while completing the quest.") - 4
		Place(log.constraintLine, child, y)
		y = y - TextHeight(log.constraintLine, limitText) - 10
	else
		log.constraintHeader:Hide()
		log.constraintNote:Hide()
		log.constraintLine:Hide()
	end
	for i = 1, 20 do
		local line = goalLines[i]
		local goal = quest.goals[i]
		if goal then
			local text = goal.name .. ": " .. goal.count .. "/" .. goal.quantity
			line:SetText(text)
			line:Show()
			Place(line, child, y)
			y = y - TextHeight(line, text) - 4
		else
			line:Hide()
		end
	end
	if quest.desc and quest.desc ~= "" then
		log.descHeader:Show()
		log.desc:Show()
		Place(log.descHeader, child, y - 8)
		y = y - 8 - TextHeight(log.descHeader, "Description") - 6
		log.desc:SetText(quest.desc)
		Place(log.desc, child, y)
		y = y - TextHeight(log.desc, quest.desc) - 12
	else
		log.descHeader:Hide()
		log.desc:Hide()
	end
	local doneText = CompletionText(quest.completed)
	if doneText then
		log.completed:SetText(doneText)
		log.completed:Show()
		Place(log.completed, child, y - 8)
		y = y - 8 - TextHeight(log.completed, doneText) - 8
	else
		log.completed:Hide()
	end
	child:SetHeight(math.max(20 - y, log.detail:GetHeight()))
end

local function BuildLog()
	local frame = CreateFrame("Frame", "ForeverMakerQuestLog", UIParent, "BackdropTemplate")
	frame:SetSize(680, 440)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("MEDIUM")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	frame:SetBackdropColor(1, 1, 1, 1)
	frame:Hide()
	tinsert(UISpecialFrames, "ForeverMakerQuestLog")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Quest Log")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	local importButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	importButton:SetSize(80, 22)
	importButton:SetPoint("TOPLEFT", 18, -36)
	importButton:SetText("Import")
	importButton:SetScript("OnClick", function()
		ForeverMaker.ShowImport()
	end)

	local count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	count:SetPoint("TOPRIGHT", -40, -40)
	count:SetText("Quests: 0")

	local listWell = frame:CreateTexture(nil, "BACKGROUND")
	listWell:SetPoint("TOPLEFT", 16, -66)
	listWell:SetPoint("BOTTOMLEFT", 16, 48)
	listWell:SetWidth(236)
	listWell:SetColorTexture(0.05, 0.04, 0.03, 1)

	local list = CreateFrame("ScrollFrame", nil, frame)
	list:SetPoint("TOPLEFT", listWell, "TOPLEFT", 4, -4)
	list:SetPoint("BOTTOMRIGHT", listWell, "BOTTOMRIGHT", -4, 4)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta)
		local step = ROW_H * 3
		local nextScroll = self:GetVerticalScroll() - (delta * step)
		if nextScroll < 0 then
			nextScroll = 0
		end
		local maxScroll = self:GetVerticalScrollRange()
		if nextScroll > maxScroll then
			nextScroll = maxScroll
		end
		self:SetVerticalScroll(nextScroll)
	end)
	local listChild = CreateFrame("Frame", nil, list)
	listChild:SetSize(220, LIST_H)
	list:SetScrollChild(listChild)

	local parchment = frame:CreateTexture(nil, "BACKGROUND")
	parchment:SetPoint("TOPLEFT", listWell, "TOPRIGHT", 8, 0)
	parchment:SetPoint("BOTTOMRIGHT", -16, 48)
	parchment:SetTexture("Interface\\QuestFrame\\QuestBG")
	parchment:SetTexCoord(0.09, 0.50, 0.08, 0.56)

	local detail = CreateFrame("ScrollFrame", "ForeverMakerQuestDetail", frame, "UIPanelScrollFrameTemplate")
	detail:SetPoint("TOPLEFT", parchment, "TOPLEFT", 12, -8)
	detail:SetPoint("BOTTOMRIGHT", parchment, "BOTTOMRIGHT", -26, 8)
	local scrollBgLeft = _G["ForeverMakerQuestDetailScrollBackgroundTopLeft"]
	local scrollBgRight = _G["ForeverMakerQuestDetailScrollBackgroundBottomRight"]
	if scrollBgLeft then
		scrollBgLeft:Hide()
	end
	if scrollBgRight then
		scrollBgRight:Hide()
	end
	local detailChild = CreateFrame("Frame", nil, detail)
	detailChild:SetSize(400, 330)
	detail:SetScrollChild(detailChild)

	local pageTitle = detailChild:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
	pageTitle:SetPoint("TOPLEFT", 12, -12)
	pageTitle:SetPoint("RIGHT", -28, 0)
	pageTitle:SetJustifyH("LEFT")

	for i = 1, 20 do
		local line = detailChild:CreateFontString(nil, "OVERLAY", "QuestFontNormalSmall")
		line:SetJustifyH("LEFT")
		line:Hide()
		goalLines[i] = line
	end

	local constraintHeader = detailChild:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
	constraintHeader:SetJustifyH("LEFT")
	constraintHeader:SetText("Constraints")
	constraintHeader:Hide()
	local constraintNote = detailChild:CreateFontString(nil, "OVERLAY", "QuestFont")
	constraintNote:SetJustifyH("LEFT")
	constraintNote:SetText("Keep within these limits while completing the quest.")
	constraintNote:Hide()
	local constraintLine = detailChild:CreateFontString(nil, "OVERLAY", "QuestFont")
	constraintLine:SetJustifyH("LEFT")
	constraintLine:Hide()

	local descHeader = detailChild:CreateFontString(nil, "OVERLAY", "QuestTitleFont")
	descHeader:SetJustifyH("LEFT")
	descHeader:SetText("Description")
	descHeader:Hide()
	local desc = detailChild:CreateFontString(nil, "OVERLAY", "QuestFont")
	desc:SetJustifyH("LEFT")
	desc:SetJustifyV("TOP")
	desc:Hide()
	local completed = detailChild:CreateFontString(nil, "OVERLAY", "QuestFont")
	completed:SetJustifyH("LEFT")
	completed:SetJustifyV("TOP")
	completed:Hide()

	local empty = frame:CreateFontString(nil, "OVERLAY", "QuestFont")
	empty:SetPoint("LEFT", detail, "LEFT", 24, 0)
	empty:SetPoint("RIGHT", detail, "RIGHT", -36, 0)
	empty:SetJustifyH("CENTER")
	empty:SetText("Paste a quest from the website.")

	local removeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	removeButton:SetSize(100, 22)
	removeButton:SetPoint("BOTTOMLEFT", 18, 16)
	removeButton:SetText("Remove")
	removeButton:SetScript("OnClick", function()
		local id = ForeverMaker.selectedId
		if not id or not ForeverMakerDB.quests[id] then
			return
		end
		ForeverMakerDB.quests[id] = nil
		for i, stored in ipairs(ForeverMakerDB.order) do
			if stored == id then
				table.remove(ForeverMakerDB.order, i)
				break
			end
		end
		ForeverMaker.selectedId = ForeverMakerDB.order[1]
		ForeverMaker.RefreshLog()
	end)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	closeButton:SetSize(80, 22)
	closeButton:SetPoint("BOTTOMRIGHT", -18, 16)
	closeButton:SetText("Close")
	closeButton:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.listChild = listChild
	frame.detail = detail
	frame.detailChild = detailChild
	frame.title = pageTitle
	frame.constraintHeader = constraintHeader
	frame.constraintNote = constraintNote
	frame.constraintLine = constraintLine
	frame.descHeader = descHeader
	frame.desc = desc
	frame.completed = completed
	frame.empty = empty
	frame.count = count
	frame.removeButton = removeButton
	frame:SetScript("OnShow", ForeverMaker.RefreshLog)
	log = frame
end

local function ShowImportError(text)
	importFrame.error:SetText(text or "")
end

local function ShowImportEditor()
	importFrame.edit:Show()
	importFrame.scroll:Show()
	importFrame.preview:Hide()
	importFrame.checkButton:Show()
	importFrame.saveButton:Hide()
	importFrame.backButton:Hide()
	ShowImportError("")
end

local function ShowImportPreview(quest)
	importFrame.pending = quest
	importFrame.edit:Hide()
	importFrame.scroll:Hide()
	importFrame.preview:Show()
	importFrame.checkButton:Hide()
	importFrame.saveButton:Show()
	importFrame.backButton:Show()
	local lines = { quest.title, "" }
	local limitText = ForeverMaker.LevelLimitText(quest)
	if limitText then
		lines[#lines + 1] = "Constraints"
		lines[#lines + 1] = "Keep within these limits while completing the quest."
		lines[#lines + 1] = limitText
		lines[#lines + 1] = ""
	end
	for _, goal in ipairs(quest.goals) do
		lines[#lines + 1] = goal.name .. ": 0/" .. goal.quantity
	end
	if quest.desc ~= "" then
		lines[#lines + 1] = ""
		lines[#lines + 1] = quest.desc
	end
	importFrame.preview:SetText(table.concat(lines, "\n"))
	ShowImportError("")
end

local function BuildImport()
	local frame = CreateFrame("Frame", "ForeverMakerImport", UIParent, "BackdropTemplate")
	frame:SetSize(460, 360)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	OpaqueFill(frame, 0.22, 0.15, 0.09)
	frame:Hide()
	tinsert(UISpecialFrames, "ForeverMakerImport")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Import quest")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, -44)
	scroll:SetPoint("BOTTOMRIGHT", -32, 72)
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(390)
	edit:SetHeight(220)
	edit:SetMaxLetters(20000)
	scroll:SetScrollChild(edit)
	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	local preview = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	preview:SetPoint("TOPLEFT", 24, -48)
	preview:SetPoint("BOTTOMRIGHT", -24, 76)
	preview:SetJustifyH("LEFT")
	preview:SetJustifyV("TOP")
	preview:Hide()

	local errorText = frame:CreateFontString(nil, "OVERLAY", "GameFontRed")
	errorText:SetPoint("BOTTOMLEFT", 20, 48)
	errorText:SetPoint("RIGHT", -20, 0)
	errorText:SetJustifyH("LEFT")
	errorText:SetText("")

	local checkButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	checkButton:SetSize(80, 22)
	checkButton:SetPoint("BOTTOMRIGHT", -16, 16)
	checkButton:SetText("Check")
	checkButton:SetScript("OnClick", function()
		local quest, err = ForeverMaker.Parse(edit:GetText())
		if not quest then
			ShowImportError(err)
			return
		end
		ShowImportPreview(quest)
	end)

	local saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	saveButton:SetSize(80, 22)
	saveButton:SetPoint("BOTTOMRIGHT", -16, 16)
	saveButton:SetText("Save")
	saveButton:Hide()
	saveButton:SetScript("OnClick", function()
		local quest = frame.pending
		if not quest then
			return
		end
		ForeverMaker.EnsureDB()
		local result = ForeverMaker.Apply(ForeverMakerDB, quest)
		if result == "older" then
			ShowImportError("This copy is older than the one you have.")
			return
		end
		ForeverMaker.selectedId = quest.id
		frame:Hide()
		if not log:IsShown() then
			log:Show()
		end
		ForeverMaker.RefreshLog()
		local saved = RESULT_TEXT[result] or "Quest saved."
		local limitText = ForeverMaker.LevelLimitText(quest)
		if limitText then
			saved = saved .. " " .. limitText .. "."
		end
		Note(saved)
	end)

	local backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	backButton:SetSize(80, 22)
	backButton:SetPoint("RIGHT", saveButton, "LEFT", -8, 0)
	backButton:SetText("Back")
	backButton:Hide()
	backButton:SetScript("OnClick", ShowImportEditor)

	frame.scroll = scroll
	frame.edit = edit
	frame.preview = preview
	frame.error = errorText
	frame.checkButton = checkButton
	frame.saveButton = saveButton
	frame.backButton = backButton
	importFrame = frame
end

function ForeverMaker.ShowImport()
	if not importFrame then
		return
	end
	importFrame.pending = nil
	importFrame.edit:SetText("")
	ShowImportEditor()
	importFrame:Show()
	importFrame.edit:SetFocus()
end

function ForeverMaker.ToggleLog()
	if not log then
		return
	end
	if log:IsShown() then
		log:Hide()
	else
		log:Show()
	end
end

function ForeverMaker.BuildFrames()
	if log then
		return
	end
	BuildLog()
	BuildImport()
end

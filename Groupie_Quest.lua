ADDON_NAME = "Groupie_Quest"
ADDON_LOADED_MSG = "Groupie Quest: Loaded"

local isDebug = true
Groupie_QuestLog = {}
Groupie_PartyQuestLog = {}

local debug_print = function(...)
    if isDebug then
        print(ADDON_NAME.." [DEBUG]: ".. ...)
    end
end

-- Set up frame etc.
local frame = CreateFrame("Frame", ADDON_NAME, UIParent)

-- Addon chat handling
local sendAddonMessage = function(message)
	local channel = "PARTY"
    debug_print("SendMessage("..ADDON_NAME..","..message..","..channel..")")
    C_ChatInfo.SendAddonMessage(ADDON_NAME, message, channel)    
end

local handleAddonMessage = function(message, sender)
	local senderName, _ = strsplit("-", sender)
	debug_print("ReceiveMessage ["..senderName.."] "..message)

	Groupie_PartyQuestLog[senderName] = { message = message }
end

-- Functions

local loadOwnQuestLog = function()
	Groupie_QuestLog = {}

	numEntries, _ = GetNumQuestLogEntries()
	debug_print(numEntries)
	for questLogIndex = 1, numEntries do
		title, _, _, isHeader, _, _, _, questID, _, _, _, _, _, _, _, _, _ = GetQuestLogTitle(questLogIndex)
		if isHeader == false then
			questEntry = { id = questID, title = title, objectives = C_QuestLog.GetQuestObjectives(questID) }
			Groupie_QuestLog[questID] = questEntry
		end
	end
end

local sendOwnQuestLog = function()
	local serializedQuestLog = ""
	
	for questID, questEntry in pairs(Groupie_QuestLog) do
		local serializedQuestEntry = questEntry.id
		serializedQuestLog = serializedQuestLog.."#"..serializedQuestEntry
	end
	
	sendAddonMessage("QL@"..serializedQuestLog)
end

-- Set up quest tracker info frames
for i=2,10 do    -- index 1 is always a header so skip that one
    local questWatchLine = _G["QuestWatchLine"..i]
    local f = CreateFrame("Frame", "GroupieQuestInfo"..i, QuestWatchFrame)
    f:SetWidth(20)
    f:SetHeight(20)
    f:SetFrameStrata("HIGH")

	-- f:SetScript("OnEnter", function(self) 
	-- 	ShowUIPanel(GameTooltip)
	-- 	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	-- 	GameTooltip:SetText(self.questInfo)
	-- 	GameTooltip:Show()
	-- end)
	-- f:SetScript("OnLeave", function(self) 
	-- 	GameTooltip:Hide()
	-- end)

    f:SetPoint("CENTER", questWatchLine, "LEFT", 0, 0)

    f.bg = f:CreateTexture(nil, "MEDIUM")
    f.bg:SetTexture("Interface/Common/BlueMenuRing")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 5)
    f.bg:SetWidth(38)
    f.bg:SetHeight(38)

    f:Show()
end


-- event handlers
local events = {
    PLAYER_LOGIN = function()
		print(ADDON_LOADED_MSG)

		loadOwnQuestLog()
		sendOwnQuestLog()
		
		C_ChatInfo.RegisterAddonMessagePrefix(ADDON_NAME)
    end,
    GROUP_ROSTER_UPDATE = function()
       
    end,
    PLAYER_XP_UPDATE = function()

    end,
    CHAT_MSG_ADDON = function(prefix, message, _, sender)        
        if prefix == ADDON_NAME then
            handleAddonMessage(message, sender)
        end        
    end
}

-- Event registering, must be last

for e,f in pairs(events) do
    frame:RegisterEvent(e)
end

frame:SetScript("OnEvent", function(self, event, ...)
    for e,f in pairs(events) do
        if e == event then
            f(...)
            break
        end
    end
end)
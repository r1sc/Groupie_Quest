ADDON_NAME = "Groupie_Quest"
ADDON_LOADED_MSG = "Groupie Quest: Loaded"

local isDebug = false
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
	
	local _, questLogEntriesText = strsplit("@", message)
	local questLogEntries = { strsplit("#", questLogEntriesText) }
	local questLog = {}
	
	for i = 2, #questLogEntries do
		local questID, objectivesText = strsplit("|", questLogEntries[i])
		local objectivesToParse = { strsplit(";", objectivesText) }
		local objectives = {}
						
		for y = 2, #objectivesToParse do
			local numFulfilled, numRequired = strsplit("/", objectivesToParse[y])
			objectives[y-1] = { numFulfilled = numFulfilled, numRequired = numRequired }
		end
		
		questLog[tonumber(questID)] = objectives
	end
	
	Groupie_PartyQuestLog[senderName] = questLog
	
	renderPartyQuestProgress()
end

-- Functions

local loadOwnQuestLog = function()
	Groupie_QuestLog = {}

	numEntries, _ = GetNumQuestLogEntries()
	
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
		if #questEntry.objectives ~= 0 then
			local serializedQuestEntry = questEntry.id.."|"
			for i, objective in pairs(questEntry.objectives) do
				serializedQuestEntry = serializedQuestEntry..";"..objective.numFulfilled.."/"..objective.numRequired
			end
			serializedQuestLog = serializedQuestLog.."#"..serializedQuestEntry
		end
	end
	
	sendAddonMessage("QL@"..serializedQuestLog)
end

isQuestObjectiveCompleted = function(questID, objectiveIndex)
	for player, quests in pairs(Groupie_PartyQuestLog) do
		if quests[questID] ~= nil then
			local objective = quests[questID][objectiveIndex]
			if objective.numFulfilled ~= objective.numRequired then
				return false
			end
		end
	end
	
	return true
end

getPartyProgressForQuestObjective = function(questID, objectiveIndex)
	local progress = ""
	for player, quests in pairs(Groupie_PartyQuestLog) do
		if quests[questID] ~= nil then
			local objective = quests[questID][objectiveIndex]
			progress = progress.."|"..player..": "..objective.numFulfilled.."/"..objective.numRequired
		end
	end
	
	return progress
end

getObjectiveName = function(questIndex, objectiveIndex)
	local text, type, finished = GetQuestLogLeaderBoard(objectiveIndex, questIndex)
	return strsplit(":", text)
end

hideQuestTracking = function()
	for i=2,10 do    -- index 1 is always a header so skip that one
		local questWatchLine = _G["GroupieQuestInfo"..i]
		questWatchLine:Hide()
	end
end

shouldTrackQuest = function(questID)
	for player, quests in pairs(Groupie_PartyQuestLog) do
		if player ~= UnitName("player") and quests[questID] ~= nil then
			return true
		end
	end
	
	return false
end

renderPartyQuestProgress = function()
	hideQuestTracking()

	if Groupie_PartyQuestLog[UnitName("player")] == nil then
		return
	end

	local questWatchLine = 1
	for i=1, GetNumQuestWatches() do
		local questIndex = GetQuestIndexForWatch(i);
		if ( questIndex ) then			
			local numObjectives = GetNumQuestLeaderBoards(questIndex);
			if ( numObjectives > 0 ) then
				local title, _, _, isHeader, _, _, _, questID, _, _, _, _, _, _, _, _, _ = GetQuestLogTitle(questIndex)
				
				questWatchLine = questWatchLine + 1
		
				for objectiveIndex = 1, numObjectives do
					
					if shouldTrackQuest(questID) then	
						local questWatchLineFrame = _G["GroupieQuestInfo"..questWatchLine]
						questWatchLineFrame:Show()
						questWatchLineFrame.objectiveName = getObjectiveName(questIndex, objectiveIndex)
						questWatchLineFrame.progress = getPartyProgressForQuestObjective(questID, objectiveIndex)
						
						if isQuestObjectiveCompleted(questID, objectiveIndex) then
							questWatchLineFrame.bg2:SetVertexColor(0,1,0)
						else 
							questWatchLineFrame.bg2:SetVertexColor(1,1,0)
						end
					end
					
					questWatchLine = questWatchLine + 1
				end
			end
		end
	end
end

-- Set up quest tracker info frames
for i=2,10 do    -- index 1 is always a header so skip that one
    local questWatchLine = _G["QuestWatchLine"..i]
    local f = CreateFrame("Frame", "GroupieQuestInfo"..i, QuestWatchFrame)
    f:SetWidth(20)
    f:SetHeight(20)
    f:SetFrameStrata("HIGH")

	f:SetScript("OnEnter", function(self) 
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:AddLine(self.objectiveName)
		local progress = { strsplit("|", self.progress) }
		for _, progressEntry in pairs(progress) do
			GameTooltip:AddLine(progressEntry,1,1,1)		
		end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(self) 
		GameTooltip:Hide()
	end)

    f:SetPoint("CENTER", questWatchLine, "LEFT", 0, 0)

    f.bg = f:CreateTexture(nil, "MEDIUM")
    f.bg:SetTexture("Interface/Buttons/UI-RadioButton")
	f.bg:SetTexCoord(0,0.25,0,1)
	--f.bg:SetVertexColor(0,0,1)
    f.bg:SetPoint("CENTER", f, "CENTER", 5, 0)
    f.bg:SetWidth(15)
    f.bg:SetHeight(15)
		
    f.bg2 = f:CreateTexture(nil, "MEDIUM")
    f.bg2:SetTexture("Interface/Buttons/UI-RadioButton")
	f.bg2:SetTexCoord(0.25,0.5,0,1)
    f.bg2:SetPoint("CENTER", f, "CENTER", 5, 0)
    f.bg2:SetWidth(15)
    f.bg2:SetHeight(15)

    f:Hide()
end


-- event handlers
local events = {
    PLAYER_LOGIN = function()
		print(ADDON_LOADED_MSG)

		C_ChatInfo.RegisterAddonMessagePrefix(ADDON_NAME)
		
		loadOwnQuestLog()
		sendOwnQuestLog()
		renderPartyQuestProgress()
    end,
    QUEST_WATCH_LIST_CHANGED = function() 
		print("QUEST_WATCH_LIST_CHANGED")  
		renderPartyQuestProgress()    
    end,    
    QUEST_ITEM_UPDATE = function()
		sendOwnQuestLog()
		renderPartyQuestProgress() 
    end,
    GROUP_ROSTER_UPDATE = function()
		sendOwnQuestLog()
		renderPartyQuestProgress() 
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
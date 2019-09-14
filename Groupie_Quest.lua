ADDON_NAME = "Groupie_Quest"
ADDON_LOADED_MSG = "Groupie Quest: Loaded"
MAX_QUESTWATCH_LINES = 30

local isDebug = false
Groupie_PartyQuestLog = {}

local debug_print = function(...)
    if isDebug then
        print(ADDON_NAME.." [DEBUG]: ".. ...)
    end
end

-- Set up frame etc.
local frame = CreateFrame("Frame", ADDON_NAME, UIParent)


-- Functions
local sendAddonMessage = function(message)
	local channel = "PARTY"
    debug_print("SendMessage("..ADDON_NAME..","..message..","..channel..")")
    C_ChatInfo.SendAddonMessage(ADDON_NAME, message, channel)    
end

local getOwnQuestLog = function()
	local questLog = {}

	numEntries, _ = GetNumQuestLogEntries()
	
	for questLogIndex = 1, numEntries do
		title, _, _, isHeader, _, _, _, questID, _, _, _, _, _, _, _, _, _ = GetQuestLogTitle(questLogIndex)
		if isHeader == false then
			questEntry = { id = questID, title = title, objectives = C_QuestLog.GetQuestObjectives(questID) }
			questLog[questID] = questEntry
		end
	end
	
	return questLog
end

local sendOwnQuestLog = function()
	local questLog = getOwnQuestLog()
	local serializedQuestLog = ""
	
	for questID, questEntry in pairs(questLog) do
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

local isQuestObjectiveCompleted = function(questID, questIndex, objectiveIndex)
	local objectiveProgress = Groupie_PartyQuestLog[questID][objectiveIndex]
	
	for player, objective in pairs(objectiveProgress) do
		if objective.fulfilled ~= objective.required then
			return false
		end
	end
	
	local _, _, finished = GetQuestLogLeaderBoard(objectiveIndex, questIndex)
	
	return finished
end

local getPartyProgressForQuestObjective = function(questID, objectiveIndex)
	return Groupie_PartyQuestLog[questID][objectiveIndex]
end

local getObjectiveName = function(questIndex, objectiveIndex)
	local text = GetQuestLogLeaderBoard(objectiveIndex, questIndex)
	return strsplit(":", text)
end

local hideQuestTracking = function()
	for i=2,MAX_QUESTWATCH_LINES do    -- index 1 is always a header so skip that one
		local questWatchLine = _G["GroupieQuestInfo"..i]
		questWatchLine:Hide()
	end
end

local shouldTrackQuest = function(questID)
	return Groupie_PartyQuestLog[questID] ~= nil
end

local syncPartyQuestLog = function()
	local partyNames = GetHomePartyInfo()
	local isInParty = function(playerName)
		for i=1,#partyNames do
			if partyNames[i] == playerName then
				return true
			end
		end
		return false
	end
	
	for questID, objectives in pairs(Groupie_PartyQuestLog) do
		for objectiveIndex=1, #objectives do
			for playerName, progress in pairs(objectives[objectiveIndex]) do
				if isInParty(playerName) == false then
					Groupie_PartyQuestLog[questID][objectiveIndex][playerName] = nil
				end
			end
		end
	end
end

local renderPartyQuestProgress = function()
	hideQuestTracking()

	if next(Groupie_PartyQuestLog) == nil then
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
						
						if isQuestObjectiveCompleted(questID, questIndex, objectiveIndex) then
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

local handleAddonMessage = function(message, senderName)
	debug_print("ReceiveMessage ["..senderName.."] "..message)
	
	if message == "REQ" then
		sendOwnQuestLog()
		return
	end
	
	local _, questLogEntriesText = strsplit("@", message)
	local questLogEntries = { strsplit("#", questLogEntriesText) }
	local questLog = {}
	
	for i = 2, #questLogEntries do
		local questIDText, objectivesText = strsplit("|", questLogEntries[i])
		local objectivesToParse = { strsplit(";", objectivesText) }
		local objectives = {}
		
		local questID = tonumber(questIDText)
		if Groupie_PartyQuestLog[questID] == nil then
			Groupie_PartyQuestLog[questID] = {}
		end
						
		for y = 2, #objectivesToParse do
			local objectiveIndex = y-1
			if Groupie_PartyQuestLog[questID][objectiveIndex] == nil then
				Groupie_PartyQuestLog[questID][objectiveIndex] = {}
			end
			
			local numFulfilled, numRequired = strsplit("/", objectivesToParse[y])
			Groupie_PartyQuestLog[questID][objectiveIndex][senderName] = { fulfilled = numFulfilled, required = numRequired }
		end
	end
	
	renderPartyQuestProgress()
end

-- Set up quest tracker info frames
for i=2,MAX_QUESTWATCH_LINES do    -- index 1 is always a header so skip that one
    local questWatchLine = _G["QuestWatchLine"..i]
    local f = CreateFrame("Frame", "GroupieQuestInfo"..i, QuestWatchFrame)
    f:SetWidth(20)
    f:SetHeight(20)
    f:SetFrameStrata("HIGH")

	f:SetScript("OnEnter", function(self) 
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:AddLine(self.objectiveName)
		for playerName, progress in pairs(self.progress) do
			GameTooltip:AddLine(playerName..": "..progress.fulfilled.."/"..progress.required,1,1,1)		
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
		C_ChatInfo.RegisterAddonMessagePrefix(ADDON_NAME)
		
		sendAddonMessage("REQ")
		sendOwnQuestLog()
		renderPartyQuestProgress()
    end,
	ADDON_LOADED = function(addonName)
        if addonName == ADDON_NAME then            
			print(ADDON_LOADED_MSG)
        else
			return false
		end
    end,
    QUEST_WATCH_LIST_CHANGED = function()  
		renderPartyQuestProgress()    
    end,    
    QUEST_LOG_UPDATE = function()
		sendOwnQuestLog()
		renderPartyQuestProgress() 
    end,
    GROUP_ROSTER_UPDATE = function()
		if IsInGroup() == false then
			Groupie_PartyQuestLog = {}
			hideQuestTracking()
		else
			syncPartyQuestLog()
			sendOwnQuestLog()
			renderPartyQuestProgress()
		end		
    end,
    CHAT_MSG_ADDON = function(prefix, message, _, sender)
		local senderName, _ = strsplit("-", sender)        
        if prefix == ADDON_NAME and senderName ~= UnitName("player") then
            handleAddonMessage(message, senderName)
        else
			return false
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
			if f(...) ~= false then
				debug_print(event)
				if ... ~= nil then
					debug_print(...)
				end				
			end
            break
        end
    end
end)
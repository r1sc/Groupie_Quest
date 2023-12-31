Groupie_Debug = false
Groupie_Quests = {}

local debug_print = function(...)
    if Groupie_Debug then
        print(...)
    end
end

local send = function(prefix, message, channel)
    debug_print("SendAddonMessage("..prefix..","..message..","..channel..")")
    C_ChatInfo.SendAddonMessage(prefix, message, channel)    
end

function GetLeaderBoardDetails (boardIndex,questIndex)
    local description, objectiveType, isCompleted = GetQuestLogLeaderBoard (boardIndex,questIndex);
    local itemName, num = strsplit(":",description)
    local numItems, numNeeded = strsplit("/", num)
    return objectiveType, itemName, numItems, numNeeded, isCompleted;
  end -- returns eg. "monster", "Young Nightsaber slain", 1, 7, nil

-- Event handling


local events = {
    ADDON_LOADED = function(addonName)
        if addonName == "Groupie_Quest" then            
            local result = C_ChatInfo.RegisterAddonMessagePrefix("Groupie_Quest")
            print("Groupie Quest: Loaded")
            
            numEntries, _ = GetNumQuestLogEntries()
            for questLogIndex = 1,numEntries do
                title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(questLogIndex)
                if isHeader == false then
                    local numLeaderboards = GetNumQuestLeaderBoards(questLogIndex)
                    questEntry = { title = title, tasks = C_QuestLog.GetQuestObjectives(questID) }
                    -- for leaderboardIndex = 1,numLeaderboards do
                    --     objectiveType, itemName, numItems, numNeeded, isCompleted = GetLeaderBoardDetails(leaderboardIndex, questLogIndex)
                    --     questEntry.tasks[leaderboardIndex] = { itemName = itemName, numItems = numItems, numNeeded = numNeeded }
                    -- end
                    Groupie_Quests[questID] = questEntry
                end
            end
        end
    end,
    GROUP_ROSTER_UPDATE = function()
        RefreshPartyXPBars()
        SendXP()
    end,
    PLAYER_XP_UPDATE = function()
        SendXP()
    end,
    CHAT_MSG_ADDON = function(prefix, message, channel, sender)        
        if prefix == "Groupie_XP" then
            local _, _, xp, xpMax = string.find(message, "(%d+)|(%d+)")
            local name, _ = strsplit("-", sender)
            if Groupie_Debug then
                debug_print("Received XP update from "..name..": Now: "..xp.." Max: "..xpMax)
            end
            
            Groupie_XPs[name] = { xp = xp, xpMax = xpMax }
            RefreshPartyXPBars()
        end        
    end
}

--- Set up frame etc.

CreateFrame("Frame", "Groupie_Quest", UIParent)
for e,f in pairs(events) do
    Groupie_Quest:RegisterEvent(e)
end
Groupie_Quest:SetScript("OnEvent", function(self, event, ...)
    for e,f in pairs(events) do
        if e == event then
            f(...)
            break
        end
    end
end)

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
Groupie_Debug = false
Groupie_XPs = {}

local debug_print = function(...)
    if Groupie_Debug then
        print(...)
    end
end

function SendXP()
    local xp = UnitXP("player")
    local xpMax = UnitXPMax("player")
    Groupie_SendAddonMessage("Groupie_XP", xp.."|"..xpMax, "PARTY")
end

function Groupie_SendAddonMessage(prefix, message, channel)
    debug_print("SendAddonMessage("..prefix..","..message..","..channel..")")
    C_ChatInfo.SendAddonMessage(prefix, message, channel)    
end

function RefreshFrame(expMarker, portraitTextureName, name, xpTable)
	SetPortraitTexture(expMarker.portrait, portraitTextureName)

	local expPercent = (xpTable.xp / xpTable.xpMax)
	expMarker:SetPoint("CENTER", MainMenuExpBar, "LEFT", expPercent * MainMenuExpBar:GetWidth(), 0)
	
	expMarker.playerName = name.." "..floor(expPercent * 100).."%"
	
	expMarker:Show()
end

function RefreshPartyXPBars()
    local numMembers = GetNumGroupMembers()
    for i=1,numMembers-1 do
        local name_i =  UnitName("party"..i)
        local expMarker = _G["PartyMember"..i.."ExpMarker"]
        local partyMemberXp = Groupie_XPs[name_i]
		
        if partyMemberXp ~= nil then            
            debug_print("Updating xp bar for "..name_i)
			RefreshFrame(expMarker, "party"..i, name_i, partyMemberXp)
            
        else
            debug_print("No xp data for "..name_i)
            expMarker:Hide()
        end
    end
end

function GetLeaderBoardDetails (boardIndex,questIndex)
    local description, objectiveType, isCompleted = GetQuestLogLeaderBoard (boardIndex,questIndex);
    local itemName, num = strsplit(":",description)
    local numItems, numNeeded = strsplit("/", num)
    return objectiveType, itemName, numItems, numNeeded, isCompleted;
  end -- returns eg. "monster", "Young Nightsaber slain", 1, 7, nil

-- Event handling

Groupie_Quests = {}

local events = {
    ADDON_LOADED = function(addonName)
        if addonName == "Groupie" then            
            local result = C_ChatInfo.RegisterAddonMessagePrefix("Groupie_XP")
            print("Groupie: Hello world! Registered addon message: "..(result and "yes" or "no"))
            
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

CreateFrame("Frame", "Groupie", UIParent)
for e,f in pairs(events) do
    Groupie:RegisterEvent(e)
end
Groupie:SetScript("OnEvent", function(self, event, ...)
    for e,f in pairs(events) do
        if e == event then
            f(...)
            break
        end
    end
end)

-- Set up party experience frames
for i=1,4 do    
    local f = CreateFrame("Frame", "PartyMember"..i.."ExpMarker", MainMenuExpBar)
    f:SetWidth(20)
    f:SetHeight(20)
    f:SetFrameStrata("HIGH")

	f:SetScript("OnEnter", function(self) 
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:SetText(self.playerName)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(self) 
		GameTooltip:Hide()
	end)

    f:SetPoint("CENTER", MainMenuExpBar, "LEFT", 0, 0)

    f.bg = f:CreateTexture(nil, "MEDIUM")
    f.bg:SetTexture("Interface/Common/BlueMenuRing")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 5)
    f.bg:SetWidth(38)
    f.bg:SetHeight(38)

    f.portrait = f:CreateTexture(nil, "BACKGROUND")
    f.portrait:SetAllPoints(true)
    f:Hide()
end
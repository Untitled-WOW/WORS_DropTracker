-- Define saved variables (they should be defined outside the main code, inside the addon)
WORS_DropTrackerDB = WORS_DropTrackerDB or {}
WORS_DropTrackerDB.npcLoots = WORS_DropTrackerDB.npcLoots or {}
WORS_DropTrackerDB.npcKills = WORS_DropTrackerDB.npcKills or {}  -- Track NPC kill count by name
WORS_DropTrackerDB.npcGuidCache = WORS_DropTrackerDB.npcGuidCache or {}  -- Cache GUIDs to prevent duplicate kill counts
WORS_DropTrackerDB.npcLootCache = WORS_DropTrackerDB.npcLootCache or {}  -- Cache loot tracking to prevent duplicate loot tracking
WORS_DropTrackerDB.lastTrackedNPC = WORS_DropTrackerDB.lastTrackedNPC or nil  -- Store last added NPC

WORS_DropTrackerDB.debugMode = WORS_DropTrackerDB.debugMode or false -- debug prints
WORS_DropTrackerDB.transparency = WORS_DropTrackerDB.transparency or 1.0 

function debugPrint(message)
    if WORS_DropTrackerDB.debugMode then  -- Corrected the condition
        print("Debug: " .. message)
    end
end

local function formatOSRSNumber(value)
    local formattedValue
    local color

    -- Ensure the value is a number
    if type(value) ~= "number" then
        return "|cffff0000Invalid Value|r"  -- Return red error if not a number
    end

    -- Values below 100,000 (Yellow)
    if value < 100000 then
        formattedValue = tostring(value)  -- Just the number itself
        color = "|cffffff00"  -- Yellow
    -- Values between 100,000 and 9.99M (White)
    elseif value >= 100000 and value <= 9999999 then
        formattedValue = math.floor(value / 1000) .. "K"  -- Format in thousands
        color = "|cffffffff"  -- White
    -- Values 10M and above (Green)
    elseif value >= 10000000 then
        formattedValue = math.floor(value / 1000000) .. "M"  -- Format in millions
        color = "|cff00ff00"  -- Green
    end

    -- Return the formatted string with color and value, ensuring no extra characters or invalid tags
    return color .. formattedValue .. "|r"
end



-- Function to track loot
local function TrackLoot(npcName, unitGUID)
    -- Only track loot if it hasn't been processed for this NPC and GUID
    WORS_DropTrackerDB.lastTrackedNPC = npcName
    if WORS_DropTrackerDB.npcLootCache[unitGUID] then
        debugPrint("Loot for NPC " .. npcName .. " with GUID " .. unitGUID .. " has already been tracked.")
        return  -- Skip loot tracking if already done
    end
    
    local lootCount = GetNumLootItems()
    if lootCount > 0 then
        debugPrint("Loot window opened for NPC: " .. npcName)  
        for slot = 1, lootCount do
            local iconPath, itemName, itemQuantity = GetLootSlotInfo(slot)
            local itemLink = GetLootSlotLink(slot)  -- Get the item link

            --print("Loot Slot: " .. slot)
            --print("Item Name: " .. tostring(itemName))
            --print("Item Quantity: " .. tostring(itemQuantity))
            --print("Icon Path: " .. tostring(iconPath))
            --print("Item Link: " .. tostring(itemLink))  

            if itemName and itemQuantity > 0 then
                -- Track loot drops for each NPC
                if not WORS_DropTrackerDB.npcLoots[npcName] then
                    WORS_DropTrackerDB.npcLoots[npcName] = {}
                end
                if not WORS_DropTrackerDB.npcLoots[npcName][itemName] then
                    WORS_DropTrackerDB.npcLoots[npcName][itemName] = { count = 0, link = itemLink, icon = iconPath }  -- Save icon path
                end
                WORS_DropTrackerDB.npcLoots[npcName][itemName].count = WORS_DropTrackerDB.npcLoots[npcName][itemName].count + itemQuantity
                WORS_DropTrackerDB.npcLoots[npcName][itemName].link = itemLink
                WORS_DropTrackerDB.npcLoots[npcName][itemName].icon = iconPath  -- Update icon path  

                debugPrint("Looted item: " .. (itemLink or itemName) .. " - Quantity: " .. itemQuantity)  
            
            elseif itemQuantity == 0 then
                -- Extract number from coin text (e.g., "5 coppers", "1 silver", etc.)
                local coinAmount = tonumber(string.match(itemName, "(%d+)"))
                if coinAmount then
                    if not WORS_DropTrackerDB.npcLoots[npcName] then
                        WORS_DropTrackerDB.npcLoots[npcName] = {}
                    end
                    if not WORS_DropTrackerDB.npcLoots[npcName]["Coins"] then
                        WORS_DropTrackerDB.npcLoots[npcName]["Coins"] = 0
                    end
                    WORS_DropTrackerDB.npcLoots[npcName]["Coins"] = WORS_DropTrackerDB.npcLoots[npcName]["Coins"] + coinAmount
                    debugPrint("Looted Coins: " .. coinAmount)
                else
                    debugPrint("Could not determine coin amount for: " .. itemName)
                end
            
            else
                debugPrint("Could not get item name or quantity for loot slot: " .. slot)  
            end
        end
    else
        debugPrint("No loot slots available!")  
    end

    -- Track NPC kill count (only once per GUID)
    if unitGUID then
        -- Check if we've already counted the kill for this NPC's GUID
        if not WORS_DropTrackerDB.npcGuidCache[unitGUID] then
            -- Increment kill count for this NPC name
            if not WORS_DropTrackerDB.npcKills[npcName] then
                WORS_DropTrackerDB.npcKills[npcName] = 0
            end
            WORS_DropTrackerDB.npcKills[npcName] = WORS_DropTrackerDB.npcKills[npcName] + 1  -- Increment kill count for this NPC name
            WORS_DropTrackerDB.npcGuidCache[unitGUID] = true  -- Mark GUID as processed for kill tracking
            debugPrint("Kill count for " .. npcName .. ": " .. WORS_DropTrackerDB.npcKills[npcName])
        else
            debugPrint("Kill for this NPC (GUID: " .. unitGUID .. ") has already been counted.")
        end
    end

    -- Mark loot as tracked for this NPC and GUID
    WORS_DropTrackerDB.npcLootCache[unitGUID] = true
end



local function CreateLootTrackerUI()
    -- Create main frame
    local WORS_DropTracker = CreateFrame("Frame", "WORS_DropTracker", UIParent)
    WORS_DropTracker:SetSize(300, 400)  -- Default width and height of the frame
    WORS_DropTracker:SetPoint("CENTER")  -- Position it in the center of the screen
    WORS_DropTracker:SetMovable(true)
    WORS_DropTracker:EnableMouse(true)
    WORS_DropTracker:RegisterForDrag("LeftButton")
    WORS_DropTracker:SetScript("OnDragStart", WORS_DropTracker.StartMoving)
    WORS_DropTracker:SetScript("OnDragStop", WORS_DropTracker.StopMovingOrSizing)
	WORS_DropTracker:SetClampedToScreen(true)
	-- Set the background color of the frame (UI container)
	WORS_DropTracker:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",  -- A simple 1x1 pixel texture
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	WORS_DropTracker:SetBackdropColor(0.12, 0.12, 0.12, WORS_DropTrackerDB.transparency)  


    -- Make the frame resizable
    WORS_DropTracker:SetResizable(true)
    WORS_DropTracker:SetMinResize(100, 100)  -- Minimum size to prevent it from becoming too small
    WORS_DropTracker:SetMaxResize(600, 600)  -- Maximum size

    -- Resize handle
    local resizeHandle = CreateFrame("Button", nil, WORS_DropTracker)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT")
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function() WORS_DropTracker:StartSizing("BOTTOMRIGHT") end)
    resizeHandle:SetScript("OnMouseUp", function() WORS_DropTracker:StopMovingOrSizing() end)

	-- Create title
    local title = WORS_DropTracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Drop Tracker")
	title:SetFont("Fonts/runescape.ttf", 18, "OUTLINE")  -- 16 font size
	
	-- Create the scrollable container for loot data
	local scrollFrame = CreateFrame("ScrollFrame", nil, WORS_DropTracker, "UIPanelScrollFrameTemplate")
	-- ***  IF Adding TITLE back change to scrollFrame:SetPoint("TOPLEFT", 10, -30) ***
	scrollFrame:SetPoint("TOPLEFT", 5, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", -5, 10)  -- Adjust this so the content will extend over the scroll bar

	-- Create content frame inside scrollable area
	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(280, 600)  -- Larger height for scrolling content
	scrollFrame:SetScrollChild(content)

	-- Move the content frame to the top-left and allow it to overlap with the scroll bar
	content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)  -- Align the content to overlap

	-- Hide the vertical and horizontal scroll bars and their buttons
	local scrollBar = scrollFrame.ScrollBar
	if scrollBar then
		-- Set scroll bar elements to fully transparent (invisible)
		scrollBar:GetThumbTexture():SetAlpha(0)  -- Hide the thumb
		local scrollUpButton = scrollBar.ScrollUpButton
		local scrollDownButton = scrollBar.ScrollDownButton
		if scrollUpButton and scrollDownButton then
			scrollUpButton:GetNormalTexture():SetAlpha(0)
			scrollUpButton:GetPushedTexture():SetAlpha(0)
			scrollUpButton:GetDisabledTexture():SetAlpha(0)
			scrollDownButton:GetNormalTexture():SetAlpha(0)
			scrollDownButton:GetPushedTexture():SetAlpha(0)
			scrollDownButton:GetDisabledTexture():SetAlpha(0)
			scrollUpButton:EnableMouse(false)
			scrollDownButton:EnableMouse(false)
		end
	end

    -- Function to update the UI with the loot data
	local function updateLootUI()
		local frameWidth = WORS_DropTracker:GetWidth()
		local iconSize = 32  -- Icon size
		local padding = 7  -- Padding between icons
		local iconsPerRow = math.floor((frameWidth - 20) / (iconSize + padding))  -- Dynamic number of icons per row

		-- Clear previous content
		if content.children then
			for _, child in pairs(content.children) do
				child:Hide()
			end
		else
			content.children = {}
		end

		-- Sort NPCs: last tracked first, then alphabetical order
		local sortedNPCs = {}
		local lastNPC = WORS_DropTrackerDB.lastTrackedNPC  -- Store last added NPC
		
		for npcName in pairs(WORS_DropTrackerDB.npcLoots) do
			if npcName ~= lastNPC then
				table.insert(sortedNPCs, npcName)
			end
		end
		table.sort(sortedNPCs)  -- Sort alphabetically

		if lastNPC and WORS_DropTrackerDB.npcLoots[lastNPC] then
			table.insert(sortedNPCs, 1, lastNPC)  -- Insert last NPC at the top
		end

		local yOffset = -10  -- Start position
		if #sortedNPCs > 0 then
			title:Hide()
		else
			title:Show()
		end

		for _, npcName in ipairs(sortedNPCs) do
			local lootData = WORS_DropTrackerDB.npcLoots[npcName]

			-- NPC Label
			local killCount = WORS_DropTrackerDB.npcKills[npcName] or 0
			
			-- Create a frame for the clickable NPC label
			local npcFrame = CreateFrame("Button", nil, content)
			npcFrame:SetPoint("TOPLEFT", padding - 5, yOffset)
			npcFrame:SetSize(200, 20) -- Adjust size based on text length

			-- Create NPC label inside the frame
			local npcLabel = npcFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			npcLabel:SetPoint("LEFT", npcFrame, "LEFT", 0, 0)
			npcLabel:SetText(npcName .. " x " .. killCount)
			npcLabel:SetFont("Fonts/runescape.ttf", 16, "OUTLINE")  -- 16 font size

			yOffset = yOffset - 30
			table.insert(content.children, npcFrame) -- Add the frame instead of just the label

			-- Adjust xOffset and yOffset before loot items
			local xOffset = 0
			yOffset = yOffset - 0  -- Space before loot icons

			-- Make the frame clickable to show reset confirmation
			npcFrame:SetScript("OnClick", function(self, button)
				-- Check if Shift is held down while clicking
				if IsShiftKeyDown() then
					-- Confirm reset all NPC data
					StaticPopupDialogs["WORS_DROPTRACKER_NPC_RESET_ALL"] = {
						text = "Reset loot and kill count for all NPCs?",
						button1 = "Yes",
						button2 = "No",
						OnAccept = function()
							-- Reset all NPCs' data
							WORS_DropTrackerDB.npcLoots = {}
							WORS_DropTrackerDB.npcKills = {}
							WORS_DropTrackerDB.npcGuidCache = {}
							WORS_DropTrackerDB.npcLootCache = {}

							-- Update UI
							print("All NPC data has been reset.")
							updateLootUI()
						end,
						timeout = 0,
						whileDead = true,
						hideOnEscape = true,
						preferredIndex = 3,
					}

					StaticPopup_Show("WORS_DROPTRACKER_NPC_RESET_ALL")
				else
					-- Reset only this specific NPC's data
					StaticPopupDialogs["WORS_DROPTRACKER_NPC_RESET"] = {
						text = "Reset loot and kill count for " .. npcName .. "?",
						button1 = "Yes",
						button2 = "No",
						OnAccept = function()
							-- Reset only this NPC's data
							WORS_DropTrackerDB.npcLoots[npcName] = nil
							WORS_DropTrackerDB.npcKills[npcName] = nil
							WORS_DropTrackerDB.npcGuidCache[npcName] = nil
							WORS_DropTrackerDB.npcLootCache[npcName] = nil

							-- Update UI
							print(npcName .. " data has been reset.")
							updateLootUI()
						end,
						timeout = 0,
						whileDead = true,
						hideOnEscape = true,
						preferredIndex = 3,
					}

					StaticPopup_Show("WORS_DROPTRACKER_NPC_RESET")
				end
			end)

			-- Tooltip and hover effects
			npcFrame:SetScript("OnEnter", function(self)
				-- Check if Shift key is held down
				local tooltipText = IsShiftKeyDown() and "Reset All NPCs" or "Reset " .. npcName

				-- Show tooltip with dynamic text
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				GameTooltip:SetText(tooltipText, 1, 1, 1, 1, true)
				GameTooltip:Show()
			end)

			npcFrame:SetScript("OnLeave", function()
				GameTooltip:Hide() -- Hide tooltip
			end)


			-- Loot icons
			for lootItem, data in pairs(lootData) do
				local lootIcon, lootQuantity, lootLink
				if lootItem == "Coins" then
					lootQuantity = data
					lootLink = nil

					-- Determine the appropriate coin icon based on quantity
					if lootQuantity >= 1500 then
						lootIcon = "Interface\\Icons\\CoinsMany.blp"
					elseif lootQuantity >= 1000 then
						lootIcon = "Interface\\Icons\\Coins1000.blp"
					elseif lootQuantity >= 250 then
						lootIcon = "Interface\\Icons\\Coins250.blp"
					elseif lootQuantity >= 100 then
						lootIcon = "Interface\\Icons\\Coins100.blp"
					elseif lootQuantity >= 25 then
						lootIcon = "Interface\\Icons\\Coins25.blp"
					elseif lootQuantity >= 5 then
						lootIcon = "Interface\\Icons\\Coins5.blp"
					elseif lootQuantity >= 4 then
						lootIcon = "Interface\\Icons\\Coins4.blp"
					elseif lootQuantity >= 3 then
						lootIcon = "Interface\\Icons\\Coins3.blp"
					elseif lootQuantity >= 2 then
						lootIcon = "Interface\\Icons\\Coins2.blp"
					else
						lootIcon = "Interface\\Icons\\Coins1.blp"
					end
				else

					lootIcon = data.icon
					lootQuantity = data.count or 1
					lootLink = data.link
				end

				-- Create icon frame
				local iconFrame = CreateFrame("Frame", nil, content)
				iconFrame:SetSize(iconSize, iconSize)

				-- Check if the icon fits in the current row, if not, move to the next row
				if (xOffset + iconSize + padding) > (frameWidth - 20) then
					xOffset = 0  -- Reset xOffset to start new row
					yOffset = yOffset - iconSize - 18  -- Move down for the new row
				end

				iconFrame:SetPoint("TOPLEFT", padding + xOffset, yOffset)

				-- Icon texture
				local icon = iconFrame:CreateTexture(nil, "BACKGROUND")
				icon:SetAllPoints(iconFrame)
				icon:SetTexture(lootIcon)

				-- Quantity text
				local quantityText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				quantityText:SetPoint("BOTTOMLEFT", iconFrame, "TOPLEFT", -3, -5)
				quantityText:SetText(formatOSRSNumber(lootQuantity))
				quantityText:SetFont("Fonts/runescape.ttf", 13, "OUTLINE")  -- 16 font size


				-- Tooltip on hover
				iconFrame:EnableMouse(true)
				iconFrame:SetScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					if lootItem == "Coins" then
						GameTooltip:SetText("Coins: " .. BreakUpLargeNumbers(lootQuantity))
					else
						GameTooltip:SetHyperlink(lootLink)
						GameTooltip:AddLine("Total: " .. BreakUpLargeNumbers(lootQuantity), 1, 1, 1)  -- Add quantity to the tooltip
					end
					GameTooltip:Show()
				end)
				iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

				-- Store references for clearing
				table.insert(content.children, iconFrame)
				table.insert(content.children, quantityText)

				-- Adjust position for next icon in the same row
				xOffset = xOffset + iconSize + padding
			end

			-- Space between NPCs
			yOffset = yOffset - 40
		end

		-- Adjust content height dynamically
		content:SetHeight(math.abs(yOffset) + 20)
	end
    
	-- Initial update
    updateLootUI()

    -- Hook resizing event to update UI dynamically
    WORS_DropTracker:SetScript("OnSizeChanged", updateLootUI)

    return frame, updateLootUI
end

-- Create the UI and hook the update function
local uiFrame, updateLootUI = CreateLootTrackerUI()

-- Event to track loot when it's opened
-- Event to track loot when it's opened
WORS_DropTracker:RegisterEvent("LOOT_OPENED")
WORS_DropTracker:RegisterEvent("PLAYER_LOGOUT")
WORS_DropTracker:SetScript("OnEvent", function(self, event)
    if event == "LOOT_OPENED" then
        local lootSourceGUID = UnitGUID("mouseover") -- Get GUID of the looted corpse
        local lootSourceName = GetUnitName("mouseover") -- Get name of the looted NPC

        -- Fallback: If no valid loot source found, try "target" (only if it's an NPC)
        if not lootSourceGUID or UnitIsPlayer("mouseover") then
            if UnitExists("target") and not UnitIsPlayer("target") then
                lootSourceGUID = UnitGUID("target")
                lootSourceName = GetUnitName("target")
            end
        end

        -- Ensure we have valid NPC loot data before tracking
        if lootSourceGUID and lootSourceName then
            debugPrint("Loot opened for NPC: " .. lootSourceName)
            TrackLoot(lootSourceName, lootSourceGUID)
        else
            debugPrint("No valid NPC found for loot tracking. Ignoring loot.")
        end

        updateLootUI()

    elseif event == "PLAYER_LOGOUT" then
        -- Reset these values on logout
        WORS_DropTrackerDB.npcGuidCache = {}
        WORS_DropTrackerDB.npcLootCache = {}
    end
end)




function toggleDropTableTransparency()  
    -- Toggle transparency based on the current setting
    if WORS_DropTrackerDB.transparency == 1.0 then
        -- 100% opacity -> 50% opacity
        WORS_DropTracker:SetBackdropColor(0.12, 0.12, 0.12, 0.5)  -- 50% transparent
        WORS_DropTrackerDB.transparency = 0.5
    elseif WORS_DropTrackerDB.transparency == 0.5 then
        -- 50% opacity -> 0% opacity
        -- This will effectively clear the background completely
        WORS_DropTracker:SetBackdropColor(0.0, 0.0, 0.0, 0)  -- Fully transparent backdrop
        WORS_DropTrackerDB.transparency = 0
    else
        -- 0% opacity -> 100% opacity (reset to fully visible)
        WORS_DropTracker:SetBackdropColor(0.12, 0.12, 0.12, 1.0)  -- Fully visible backdrop
        WORS_DropTrackerDB.transparency = 1.0
    end
end

-- Minimap Icon for WORS_DropTracker using LibDBIcon and Ace3
local addon = LibStub("AceAddon-3.0"):NewAddon("WORS_DropTracker")
WORS_DropTrackerMinimapButton = LibStub("LibDBIcon-1.0", true)
local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("WORS_DropTracker", {
    type = "data source",
    text = "WORS DropTracker",
    icon = "Interface\\Icons\\CoinsMany.blp", -- Replace with the desired icon
    OnClick = function(self, btn)
        if btn == "LeftButton" then
			if WORS_DropTracker:IsShown() then
				WORS_DropTracker:Hide()
			else
				WORS_DropTracker:Show()
			end        
		elseif btn == "RightButton" then
            if WORS_DropTracker:IsShown() then
                toggleDropTableTransparency()
            else
                WORS_DropTracker:Show()
                toggleDropTableTransparency()
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then
            return
        end
        tooltip:AddLine("WORS DropTracker\n\nLeft-click: Toggle WORS DropTracker Window", nil, nil, nil, nil)
        tooltip:AddLine("Right-click: Toggle Transparency 50% or 100%", nil, nil, nil, nil)
    end,
})

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("WORS_DropTrackerMinimapDB", {
        profile = {
            minimap = {
                hide = false,
                minimapPos = 190, -- This is the hardcoded position (in degrees)
            },
        },
    })
    WORS_DropTrackerMinimapButton:Register("WORS_DropTracker", miniButton, self.db.profile.minimap)
end
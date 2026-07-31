

local L = LootCollector
local MinimapButton = L:NewModule("MinimapButton")

local button = nil
local dragFrame = nil

local DEFAULT_POSITION = 200 

local function UpdateButtonPosition(angle)
    if not button then return end
    
    local x, y
    local q = math.rad(angle or DEFAULT_POSITION)
    local radius = 80 
    
    x = math.cos(q) * radius
    y = math.sin(q) * radius
    
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if button then return button end
    
    button = CreateFrame("Button", "LootCollectorMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(26)
    icon:SetHeight(26)
    icon:SetPoint("CENTER", button, "CENTER", 0, 1)
    icon:SetTexture("Interface\\AddOns\\LootCollector\\media\\MinimapIcon")
    button.icon = icon

    local lcText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lcText:SetPoint("CENTER", icon, "CENTER", 1, -1)
    lcText:SetText("LC")
    lcText:SetFont("Fonts\\FRIZQT__.ttf", 10, "OUTLINE")
    lcText:SetTextColor(1, 1, 1, 0.3)
    lcText:Hide()
    button.lcText = lcText
    
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.overlay = overlay
    
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffe5cc80LootCollector|r |cff888888(build " .. (L.BuildStamp or "?") .. ")|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click to open Discoveries", 0.7, 0.7, 1)
        GameTooltip:AddLine("Right-click to open Options", 0.7, 0.7, 1)
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)

        -- Live status: what the addon is doing right now.
        GameTooltip:AddLine(" ")
        local queue = L.db and L.db.global and L.db.global.cacheQueue
        local qn = queue and #queue or 0
        if qn > 0 then
            GameTooltip:AddLine(string.format("Caching item data: %d server lookups queued", qn), 0.6, 1, 0.6)
        else
            GameTooltip:AddLine("Item caching: idle", 0.6, 1, 0.6)
        end
        local p = L.db and L.db.profile
        local sharingOn = p and p.sharing and p.sharing.enabled
        local channelOn = sharingOn and p.sharing.publicChannelEnabled
        if not sharingOn then
            GameTooltip:AddLine("Sharing: |cffff5555disabled|r (not syncing with other players)", 0.9, 0.6, 0.6)
        elseif not channelOn then
            GameTooltip:AddLine("Public channel sync: |cffff5555off|r", 0.9, 0.6, 0.6)
        else
            local Comm = L:GetModule("Comm", true)
            if Comm and Comm.GetPublicChannelCongestionStatus then
                local st = Comm:GetPublicChannelCongestionStatus()
                if st.suspended then
                    GameTooltip:AddLine(string.format(
                        "LC channel: |cffff0000Suspended|r (~%d msgs/min, resume in %ds)",
                        st.mpm, st.remaining or 0
                    ), 1, 0.5, 0.5)
                else
                    GameTooltip:AddLine(string.format(
                        "LC channel: |cff%s%s|r (~%d msgs/min)",
                        st.colorHex, st.label, st.mpm
                    ), 0.6, 0.8, 1)
                end
                if Comm.GetOutgoingQueueSize and Comm:GetOutgoingQueueSize() > 0 then
                    GameTooltip:AddLine(string.format("Outgoing shares queued: %d", Comm:GetOutgoingQueueSize()), 1, 0.8, 0.5)
                end
            end
        end

        GameTooltip:Show()
        GameTooltip:SetFrameStrata("TOOLTIP")
    end)
    
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            local Viewer = L:GetModule("Viewer", true)
            if Viewer then Viewer:Toggle() end
        elseif btn == "RightButton" then
            InterfaceOptionsFrame_OpenToCategory("LootCollector")
            InterfaceOptionsFrame_OpenToCategory("LootCollector")
        end
    end)
    
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            if angle < 0 then angle = angle + 360 end
            UpdateButtonPosition(angle)
            if L.db and L.db.profile then
                L.db.profile.minimapButtonAngle = angle
            end
        end)
    end)
    
    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)
    
    local savedAngle = L.db and L.db.profile and L.db.profile.minimapButtonAngle or DEFAULT_POSITION
    UpdateButtonPosition(savedAngle)
    
    button:Show()
    return button
end

function MinimapButton:Show()
    if not button then
        CreateMinimapButton()
    else
        button:Show()
    end
    
    if L.db and L.db.profile then
        L.db.profile.minimapButtonHidden = false
    end
end

function MinimapButton:Hide()
    if button then
        button:Hide()
    end
    
    if L.db and L.db.profile then
        L.db.profile.minimapButtonHidden = true
    end
end

function MinimapButton:Toggle()
    if button and button:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MinimapButton:IsShown()
    return button and button:IsShown()
end

function MinimapButton:OnInitialize()
    
    if L.db and L.db.profile then
        if L.db.profile.minimapButtonHidden == nil then
            L.db.profile.minimapButtonHidden = false
        end
        if L.db.profile.minimapButtonAngle == nil then
            L.db.profile.minimapButtonAngle = DEFAULT_POSITION
        end
    end
    
    
    C_Timer.After(1, function()
        if L.db and L.db.profile and not L.db.profile.minimapButtonHidden then
            self:Show()
        end
    end)
end

return MinimapButton


local L = LootCollector
local Arrow = L:NewModule("Arrow", "AceEvent-3.0")

local UPDATE_INTERVAL = 2.0
-- 0 = never switch to TomTom's down graphic. Arrow stays directional until
-- loot (Hide if auto-track off, next pin if on). Do not use 1e6 (always down).
local CRAZY_ARROW_ARRIVAL_YARDS = 0
local LOOT_DISTANCE_THRESHOLD_SQ = (0.01 * 0.01) 

local Arrow_updateFrame = nil
Arrow.elapsed = 0

Arrow.currentTarget = nil 
Arrow.manualTarget = nil  
Arrow.tomtomUID = nil
Arrow.enabled = false 
Arrow.lastTrackedTarget = nil

Arrow.sessionSkipList = {}
Arrow._scanKey = nil

local function SnapshotTrackedTarget(d)
    if not d or type(d) ~= "table" or not d.g or not d.xy then return nil end
    return {
        g = d.g,
        i = d.i,
        il = d.il,
        xy = d.xy,
        c = d.c,
        z = d.z,
        iz = tonumber(d.iz) or 0,
        dt = d.dt,
        onHold = d.onHold,
        o = d.o,
        fp = d.fp,
        bySelf = d.bySelf,
        isLocal = d.isLocal,
    }
end

function Arrow:RememberTrackedTarget(d)
    local snap = SnapshotTrackedTarget(d)
    if snap then
        self.lastTrackedTarget = snap
    end
end

-- Prefer the live DB record when resuming so looted/onHold state stays current.
function Arrow:ResolveTrackedTarget(snap)
    if not snap or not snap.g then return nil end
    local db = L:GetDiscoveriesDB()
    local vendors = L:GetVendorsDB()
    local live = (db and db[snap.g]) or (vendors and vendors[snap.g])
    if live and live.xy then return live end
    return snap
end

local function isMine(rec)
    local me = UnitName and UnitName("player")
    if not me or not rec then return false end
    
    local names = { rec.o, rec.fp }
    for _, n in ipairs(names) do
        if type(n) == "string" and n ~= "" then
            if n == me or n:find("^"..me.."%-") then
                return true
            end
        end
    end
    
    if rec.bySelf == true or rec.isLocal == true then
        return true
    end
    return false
end

local function IsTomTomAvailable() return _G.TomTomAddZWaypoint or (_G.TomTom and _G.TomTom.AddZWaypoint) end

local function EmptyTomTomCallbacks()
    return { minimap = {}, world = {}, distance = {} }
end

local function StripTomTomDistanceCallbacks(uid)
    if type(uid) ~= "table" then return end
    if uid.dlist then wipe(uid.dlist) end
    if uid.callbacks and uid.callbacks.distance then wipe(uid.callbacks.distance) end
end

local function TT_AddZWaypoint(c, z, x, y, desc)
    if not IsTomTomAvailable() then return end
    x, y = (x or 0) * 100, (y or 0) * 100

    -- AddZWaypoint always stamps profile.persistence.cleardistance onto the
    -- callback table (default 10yd -> RemoveWaypoint). Force 0 for this pin.
    local persist = (_G.TomTom and TomTom.profile and TomTom.profile.persistence)
        or (_G.TomTom and TomTom.db and TomTom.db.profile and TomTom.db.profile.persistence)
    local oldClear = persist and persist.cleardistance
    if persist then persist.cleardistance = 0 end

    local uid
    local ok = pcall(function()
        if _G.TomTom and _G.TomTom.AddZWaypoint then
            uid = TomTom:AddZWaypoint(c, z, x, y, desc, false, false, true, EmptyTomTomCallbacks(), true, false)
        elseif _G.TomTomAddZWaypoint then
            uid = TomTomAddZWaypoint(c, z, x, y, desc, false, false, true, EmptyTomTomCallbacks(), true, false)
        end
    end)

    if persist then persist.cleardistance = oldClear end
    if not ok then return nil end
    StripTomTomDistanceCallbacks(uid)
    return uid
end

local function TT_RemoveWaypoint(uid)
    if not uid or not IsTomTomAvailable() then return end
    if _G.TomTom and _G.TomTom.RemoveWaypoint then TomTom:RemoveWaypoint(uid)
    elseif _G.TomTomRemoveWaypoint then TomTomRemoveWaypoint(uid) end
end

local function TT_SetCrazyArrow(uid, title)
    if not IsTomTomAvailable() then return end
    if _G.TomTom and _G.TomTom.SetCrazyArrow then TomTom:SetCrazyArrow(uid, CRAZY_ARROW_ARRIVAL_YARDS, title)
    elseif _G.TomTomSetCrazyArrow then TomTomSetCrazyArrow(uid, CRAZY_ARROW_ARRIVAL_YARDS, title) end
end

local function WaypointTitle(d)
    return (d and d.il and d.il:match("%[(.+)%]")) or "Discovery"
end

local function ValidPlayerMapPos(px, py)
    if not px or not py then return nil, nil end
    if px == 0 and py == 0 then return nil, nil end
    return px, py
end

local function TT_ClearCrazyArrow()
    if not IsTomTomAvailable() then return end
    if _G.TomTom and _G.TomTom.SetCrazyArrow then TomTom:SetCrazyArrow(nil)
    elseif _G.TomTomSetCrazyArrow then TomTomSetCrazyArrow(nil) end
end

local function TT_GetDistanceToWaypoint(uid)
    if not uid or not IsTomTomAvailable() then return nil end
    if _G.TomTom and _G.TomTom.GetDistanceToWaypoint then return TomTom:GetDistanceToWaypoint(uid)
    elseif _G.TomTomGetDistanceToWaypoint then return TomTomGetDistanceToWaypoint(uid) end
end

-- TomTom Crazy Arrow OnUpdate Hide()s when Astrolabe returns nil distance
-- (subzone / map-index flap). Swallowing Hide kept the frame visible but
-- froze heading and yards. While LC owns the pin, paint from LC distance.
local TWOPI = math.pi * 2
local lcPaintLastDist, lcPaintSpeed, lcPaintTta = 0, 0, 0

local function ArrowOwnsCrazyArrow()
    if Arrow._allowCrazyHide then return false end
    if not Arrow.enabled or not Arrow.tomtomUID then return false end
    if not (Arrow.manualTarget or Arrow.currentTarget) then return false end
    if IsInInstance and IsInInstance() then return false end
    return true
end

local function RefreshPlayerMapIfClosed()
    if WorldMapFrame and WorldMapFrame:IsVisible() then return end
    if not SetMapToCurrentZone then return end
    local now = GetTime and GetTime() or 0
    if now - (Arrow._lastMapFix or 0) < 0.5 then return end
    Arrow._lastMapFix = now
    SetMapToCurrentZone()
end

local function PaintLCCrazyArrow(self, elapsed)
    local target = Arrow.manualTarget or Arrow.currentTarget
    if not target or not target.xy then return false end

    local px, py, pc, pz = Arrow:GetPlayerSnapshot()
    if not px then
        RefreshPlayerMapIfClosed()
        px, py, pc, pz = Arrow:GetPlayerSnapshot()
    end
    if not px then return false end

    local dist, xDelta, yDelta = L:ComputeDistance(
        pc, pz, px, py,
        target.c, target.z, target.xy.x or 0, target.xy.y or 0
    )
    if not dist then
        RefreshPlayerMapIfClosed()
        px, py, pc, pz = Arrow:GetPlayerSnapshot()
        if px then
            dist, xDelta, yDelta = L:ComputeDistance(
                pc, pz, px, py,
                target.c, target.z, target.xy.x or 0, target.xy.y or 0
            )
        end
    end
    if not dist or not xDelta then return false end

    if not self:IsShown() then self:Show() end
    if self.status then
        self.status:SetText(string.format("%d yards", dist))
    end

    local arrow = self.arrow
    if arrow then
        -- Astrolabe-0.4 GetDirectionToIcon, then TomTom subtracts facing.
        local dir = math.atan2(xDelta, -(yDelta))
        if dir > 0 then
            dir = TWOPI - dir
        else
            dir = -dir
        end
        local facing = (GetPlayerFacing and GetPlayerFacing()) or 0
        local angle = dir - facing
        local cell = math.floor(angle / TWOPI * 108 + 0.5) % 108
        if cell < 0 then cell = cell + 108 end
        local column = cell % 9
        local row = math.floor(cell / 9)
        arrow:SetHeight(56)
        arrow:SetWidth(42)
        arrow:SetTexture("Interface\\AddOns\\TomTom\\Images\\Arrow")
        arrow:SetTexCoord(
            (column * 56) / 512, ((column + 1) * 56) / 512,
            (row * 42) / 512, ((row + 1) * 42) / 512
        )
        local db = _G.TomTom and TomTom.db and TomTom.db.profile and TomTom.db.profile.arrow
        if db and db.goodcolor then
            arrow:SetVertexColor(unpack(db.goodcolor))
        end
    end

    lcPaintTta = lcPaintTta + (elapsed or 0)
    if self.tta and lcPaintTta >= 1.0 then
        local currentSpeed = (lcPaintLastDist - dist) / lcPaintTta
        if lcPaintLastDist == 0 then currentSpeed = 0 end
        lcPaintSpeed = currentSpeed
        if lcPaintSpeed > 0 then
            local eta = math.abs(dist / lcPaintSpeed)
            self.tta:SetFormattedText("%01d:%02d", eta / 60, eta % 60)
        else
            self.tta:SetText("***")
        end
        lcPaintLastDist = dist
        lcPaintTta = 0
    end
    return true
end

local function HookCrazyArrowKeepAlive()
    local crazy = _G.TomTomCrazyArrow
    if not crazy then return end

    if not crazy._lcKeepVisible then
        crazy._lcKeepVisible = true
        local origHide = crazy.Hide
        crazy.Hide = function(self)
            if ArrowOwnsCrazyArrow() then
                return
            end
            return origHide(self)
        end
    end

    if crazy._lcOnUpdateWrapped then return end
    local origOnUpdate = crazy:GetScript("OnUpdate")
    if not origOnUpdate then return end
    crazy._lcOnUpdateWrapped = true
    crazy:SetScript("OnUpdate", function(self, elapsed)
        if ArrowOwnsCrazyArrow() then
            if not PaintLCCrazyArrow(self, elapsed) then
                -- Keep last heading/yards; TomTom's OnUpdate would freeze here.
                if not self:IsShown() then self:Show() end
            end
            return
        end
        origOnUpdate(self, elapsed)
    end)
end

local function SaveMapState()
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        return GetCurrentMapContinent and GetCurrentMapContinent() or 0,
               GetCurrentMapZone and GetCurrentMapZone() or 0,
               GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0
    end
    return nil, nil, nil
end

local function RestoreMapState(c,z,dl)
    if c and z and SetMapZoom then SetMapZoom(c,z) end
    if dl and SetDungeonMapLevel then SetDungeonMapLevel(dl) end
end

-- One read, no Restore when the world map is closed. Reuses Map's cache so
-- Arrow does not SetMapToCurrentZone on top of the minimap ticker.
function Arrow:GetPlayerSnapshot()
    local Map = L:GetModule("Map", true)
    if Map and Map.GetPlayerLocation then
        local c, mapID, px, py = Map:GetPlayerLocation()
        px, py = ValidPlayerMapPos(px, py)
        return px, py, c, mapID
    end
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        local px, py = ValidPlayerMapPos(GetPlayerMapPosition("player"))
        return px, py, GetCurrentMapContinent and GetCurrentMapContinent() or 0,
            GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    end
    if SetMapToCurrentZone then SetMapToCurrentZone() end
    local px, py = ValidPlayerMapPos(GetPlayerMapPosition("player"))
    return px, py, GetCurrentMapContinent and GetCurrentMapContinent() or 0,
        GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
end

function Arrow:GetPlayerPos()
    local px, py = self:GetPlayerSnapshot()
    return px, py
end

function Arrow:GetPlayerLocation()
    local _, _, c, mapID = self:GetPlayerSnapshot()
    return c, mapID
end

function Arrow:ClearSessionSkipList()
    wipe(self.sessionSkipList)
    print("|cff00ff00LootCollector:|r Session skip list has been cleared.")
    self:UpdateArrow(true)
    self:UpdateSkipBar()
end

function Arrow:HasSkipableTarget()
    if not self.enabled then return false end
    local target = self.manualTarget or self.currentTarget
    return target and target.g and true or false
end

function Arrow:SkipNearest()
    -- UpdateArrow no-ops while DropDownList1 is shown (TomTom / EasyMenu).
    if CloseDropDownMenus then CloseDropDownMenus() end

    local target = self.manualTarget or self.currentTarget
    local guid = target and target.g
    if not self.enabled or not guid then
        print("|cffff7f00LootCollector:|r No active target to skip.")
        return
    end

    self.sessionSkipList[guid] = true
    print(string.format("|cff00ff00LootCollector:|r Skipped tracking of: %s", target.il or "discovery"))

    -- Leave currentTarget set so UpdateArrow can pick the next pin before
    -- replacing the waypoint (avoids a blank Crazy Arrow / Skip bar).
    if self.manualTarget and self.manualTarget.g == guid then
        self.manualTarget = nil
    end
    if self.lastTrackedTarget and self.lastTrackedTarget.g == guid then
        self.lastTrackedTarget = nil
    end
    self._scanKey = nil
    self:UpdateArrow(true)
    self:UpdateSkipBar()
end

local function IsAutoTrackEnabled()
    local f = L.GetFilters and L:GetFilters()
    if f then return f.autoTrackNearest and true or false end
    return L.db and L.db.char and L.db.char.mapFilters and L.db.char.mapFilters.autoTrackNearest and true or false
end

local function ItemMatchesTracked(itemID, trackedID)
    itemID, trackedID = tonumber(itemID), tonumber(trackedID)
    if not itemID or not trackedID then return false end
    if itemID == trackedID then return true end
    if L.GetBaseItemID and L:GetBaseItemID(itemID) == L:GetBaseItemID(trackedID) then
        return true
    end
    return false
end

local function CountTrackedItemInBags(trackedID)
    trackedID = tonumber(trackedID)
    if not trackedID or not GetContainerNumSlots or not GetContainerItemLink then return 0 end
    local n = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            local id = link and tonumber(link:match("item:(%d+)"))
            if id and ItemMatchesTracked(id, trackedID) then
                local count = 1
                if GetContainerItemInfo then
                    local _, c = GetContainerItemInfo(bag, slot)
                    count = tonumber(c) or 1
                end
                n = n + count
            end
        end
    end
    return n
end

function Arrow:SnapshotTrackedBagCount(d)
    local id = d and tonumber(d.i)
    self._bagCountAtNav = id and CountTrackedItemInBags(id) or 0
end

function Arrow:DismissBecauseLooted()
    local target = self.manualTarget or self.currentTarget
    if not target then return end
    L._debug("Arrow", "DismissBecauseLooted: " .. tostring(target.g))
    if target.g then
        self.sessionSkipList[target.g] = true
    end
    self.manualTarget = nil
    if not IsAutoTrackEnabled() then
        self:Hide()
    else
        self:UpdateArrow(true)
        if self.currentTarget then
            print("|cff00ff00LootCollector:|r Tracking next nearest unlooted.")
        else
            self:Hide()
        end
    end
end

function Arrow:ClearIfTrackedItemArrivedInBags()
    if not self.enabled then return end
    local target = self.manualTarget or self.currentTarget
    if not target or not target.i then return end
    local n = CountTrackedItemInBags(target.i)
    if n > (self._bagCountAtNav or 0) then
        self._bagCountAtNav = n
        self:DismissBecauseLooted()
    end
end

function Arrow:OnBagUpdate()
    if not self.enabled then return end
    if self._bagClearPending then return end
    self._bagClearPending = true
    local function check()
        self._bagClearPending = nil
        self:ClearIfTrackedItemArrivedInBags()
    end
    if L.ScheduleAfter then
        L:ScheduleAfter(0.2, check)
    else
        check()
    end
end

local function MakeSkipBarButton(parent, label, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(16)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(label)
    b:SetFontString(fs)
    b:SetWidth(math.max(44, (fs:GetStringWidth() or 32) + 10))
    b:SetHighlightFontObject(GameFontHighlightSmall)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return b
end

function Arrow:EnsureSkipBar()
    HookCrazyArrowKeepAlive()
    local parent = _G.TomTomCrazyArrow
    if not parent then return nil end

    if self.skipBar and self.skipBar:GetParent() == parent then
        return self.skipBar
    end

    local bar = CreateFrame("Frame", "LootCollectorArrowSkipBar", parent)
    bar:SetHeight(20)
    bar:SetWidth(108)
    bar:SetPoint("TOP", parent, "BOTTOM", 0, -40)
    bar:SetFrameStrata(parent:GetFrameStrata() or "HIGH")
    bar:SetFrameLevel((parent:GetFrameLevel() or 1) + 8)
    bar:EnableMouse(true)
    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        bar:SetBackdropColor(0, 0, 0, 0.75)
        bar:SetBackdropBorderColor(0.90, 0.80, 0.50, 0.9)
    end

    local skip = MakeSkipBarButton(bar, "Skip", function()
        Arrow:SkipNearest()
    end, "Skip this item for this session. Arrow picks the next nearest match.")
    skip:SetPoint("LEFT", bar, "LEFT", 6, 0)

    local clear = MakeSkipBarButton(bar, "Clear", function()
        Arrow:ClearSessionSkipList()
    end, "Clear the session skip list.")
    clear:SetPoint("RIGHT", bar, "RIGHT", -6, 0)

    bar.skipBtn = skip
    bar.clearBtn = clear
    bar:Hide()
    self.skipBar = bar
    return bar
end

function Arrow:UpdateSkipBar()
    local bar = self:EnsureSkipBar()
    if not bar then return end
    local crazy = _G.TomTomCrazyArrow
    if crazy and crazy:IsShown() and self.enabled and self:HasSkipableTarget() then
        bar:Show()
    else
        bar:Hide()
    end
end

function Arrow:TryResumeAutoTrack()
    if L.LEGACY_MODE_ACTIVE then return false end
    if not IsAutoTrackEnabled() then return false end
    if L.IsPaused and L:IsPaused() then return false end
    if not IsTomTomAvailable() then return false end
    if not self.enabled then
        self:Show()
    else
        self:UpdateArrow(true)
        self:StartUpdates()
    end
    self:UpdateSkipBar()
    return self.enabled and true or false
end

function Arrow:ScheduleAutoTrackResume()
    if self._autoTrackResumePending then return end
    if not IsAutoTrackEnabled() then return end
    self._autoTrackResumePending = true
    local attempts = 0
    local function tick()
        attempts = attempts + 1
        if not IsAutoTrackEnabled() then
            self._autoTrackResumePending = nil
            return
        end
        local started = self:TryResumeAutoTrack()
        if started or attempts >= 10 then
            self._autoTrackResumePending = nil
            return
        end
        if L.ScheduleAfter then
            L:ScheduleAfter(2.0, tick)
        end
    end
    if L.ScheduleAfter then
        L:ScheduleAfter(1.5, tick)
    else
        tick()
    end
end

function Arrow:OnPlayerLootedItem(event, itemID, c, z, x, y)
    L._debug("Arrow", "OnPlayerLootedItem() event received.")
    if not self.enabled then return end

    local target = self.manualTarget or self.currentTarget
    if not target then return end

    if not ItemMatchesTracked(itemID, target.i) then return end

    -- Chat loot can fire after bags-full retry with stale/zero coords.
    -- Same item in-zone is enough; bag-count is the backup if this is skipped.
    local sameZone = (not c or not z or not target.c or not target.z)
        or (target.c == c and target.z == z)
    if not sameZone then return end

    local dist = L:ComputeDistance(target.c, target.z, target.xy.x, target.xy.y, c, z, x, y)
    local Constants = L:GetModule("Constants", true)
    local CLUSTER_YARDS = 40
    if Constants then
        if target.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL then CLUSTER_YARDS = Constants.CLUSTER_YARDS_MS or 200
        elseif target.dt == Constants.DISCOVERY_TYPE.BLACKMARKET then CLUSTER_YARDS = Constants.CLUSTER_YARDS_VEND or 20
        else CLUSTER_YARDS = Constants.CLUSTER_YARDS_WF or 100 end
    end

    if dist == nil or dist <= CLUSTER_YARDS then
        self:DismissBecauseLooted()
    end
end

function Arrow:OnPlayerEnteringWorld()
    self:ScheduleAutoTrackResume()
end

function Arrow:OnEnable()
    if L.LEGACY_MODE_ACTIVE then return end
    self:ScheduleAutoTrackResume()
end

function Arrow:OnInitialize()
    if L.LEGACY_MODE_ACTIVE then return end
    self:RegisterMessage("LOOTCOLLECTOR_PLAYER_LOOTED_ITEM", "OnPlayerLootedItem")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
    HookCrazyArrowKeepAlive()
    self:ScheduleAutoTrackResume()
end

function Arrow:StartUpdates() 
    L._debug("Arrow", "StartUpdates() called.")
    HookCrazyArrowKeepAlive()
    
    
    if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
        if self._ticker then return end
        self._ticker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
            Arrow:UpdateArrow()
        end)
    else
        
        if not Arrow_updateFrame then 
            Arrow_updateFrame = CreateFrame("Frame")
        end       
        Arrow.elapsed = 0
        Arrow_updateFrame:SetScript("OnUpdate", function(_, e) 
            e = math.min(e, 0.1)
            Arrow.elapsed = Arrow.elapsed + e 
            if Arrow.elapsed >= UPDATE_INTERVAL then 
                Arrow.elapsed = 0
                Arrow:UpdateArrow()
            end 
        end)
    end
end

function Arrow:StopUpdates() 
    L._debug("Arrow", "StopUpdates() called.")
    
    if self._ticker then
        self._ticker:Cancel()
        self._ticker = nil
    end
    
    if Arrow_updateFrame then 
        Arrow_updateFrame:SetScript("OnUpdate", nil)
    end
    Arrow.elapsed = 0 
end

function Arrow:NavigateTo(discovery)
    L._debug("Arrow", "NavigateTo() called for discovery: " .. (discovery and discovery.il or "nil"))
    if not IsTomTomAvailable() then print("|cffff7f00LootCollector:|r TomTom not available."); self.enabled=false; return end
    if not self:CanNavigateRecord(discovery) then
        print("|cffff7f00LootCollector:|r Cannot navigate to this discovery (it may be on hold).")
        return
    end
    self.enabled=true
    self.manualTarget=discovery
    if discovery and discovery.g then
        self.sessionSkipList[discovery.g] = nil
    end
    self:RememberTrackedTarget(discovery)
    self:SnapshotTrackedBagCount(discovery)
    self:UpdateArrow(true)
    self:StartUpdates()
    self:UpdateSkipBar()
end

function Arrow:Show() 
    L._debug("Arrow", "Show() called.")
    if not IsTomTomAvailable() then 
        print("|cffff7f00LootCollector:|r TomTom not available.")
        self.enabled=false
        return 
    end
    self.enabled=true
    self.waypointFailed=nil
    self._scanKey=nil
    self._invalidWaypointTicks=nil

    -- Resume the last tracked discovery even if it is in another zone.
    -- Fall back to in-zone auto-pick when there is nothing to resume.
    local resume = self.lastTrackedTarget and self:ResolveTrackedTarget(self.lastTrackedTarget)
    if resume and self:CanNavigateRecord(resume) then
        self.manualTarget = resume
    else
        self.manualTarget = nil
    end

    self:UpdateArrow(true)
    self:StartUpdates()
    self:UpdateSkipBar()
end

function Arrow:Hide() 
    L._debug("Arrow", "Hide() called.")
    -- Keep lastTrackedTarget so /lcarrow can resume cross-zone navigation.
    local active = self.manualTarget or self.currentTarget
    if active then
        self:RememberTrackedTarget(active)
    end
    self.enabled=false
    self.manualTarget=nil
    self.currentTarget=nil
    self.waypointFailed=nil
    self._scanKey=nil
    self._invalidWaypointTicks=nil
    self:StopUpdates()
    self:ClearTomTomWaypoint()
    if self.skipBar then self.skipBar:Hide() end
end

function Arrow:Toggle() 
    L._debug("Arrow", "Toggle() called. Current state: " .. (self.enabled and "Enabled" or "Disabled"))
    if self.enabled then 
        self:Hide()
        print("|cff00ff00LootCollector:|r Navigation arrow off.")
    else 
        self:Show()
        if not self.enabled then
            return
        end
        if self.tomtomUID or self.currentTarget or self.manualTarget then
            print("|cff00ff00LootCollector:|r Navigation arrow on.")
        else
            print("|cffff7f00LootCollector:|r Arrow enabled, but nothing to track. Navigate to a pin, or move to a zone with matching discoveries.")
        end
    end 
end

function Arrow:SlashCommandHandler(msg)
    msg = msg and msg:match("^%s*(.-)%s*$") or ""
    if msg == "clearskip" then
        self:ClearSessionSkipList()
    else
        self:Toggle()
    end
end

function Arrow:ClearTomTomWaypoint()
    self._allowCrazyHide = true
    if self.tomtomUID then
        L._debug("Arrow", "ClearTomTomWaypoint() called. Current TomTom UID: " .. tostring(self.tomtomUID))
        TT_RemoveWaypoint(self.tomtomUID)
        self.tomtomUID = nil
        TT_ClearCrazyArrow()
    end
    self._allowCrazyHide = false
end

function Arrow:ApplyTomTomWaypoint(d)
    if not d or not d.xy then return false end
    HookCrazyArrowKeepAlive()
    local itemName = WaypointTitle(d)
    local mapOpen = WorldMapFrame and WorldMapFrame:IsVisible()
    local userC, userZ, userDL
    if mapOpen then
        userC, userZ, userDL = SaveMapState()
    end
    if SetMapByID then SetMapByID((d.z or 0) - 1) end
    L._debug("Arrow", string.format("Sending waypoint to TomTom. Continent: %s, AreaID: %s", tostring(d.c), tostring(d.z)))
    self.tomtomUID = TT_AddZWaypoint(d.c, d.z, d.xy.x or 0, d.xy.y or 0, itemName)
    if mapOpen then
        RestoreMapState(userC, userZ, userDL)
    elseif SetMapToCurrentZone then
        SetMapToCurrentZone()
    end
    if self.tomtomUID then
        self.waypointFailed = nil
        self._invalidWaypointTicks = 0
        lcPaintLastDist, lcPaintSpeed, lcPaintTta = 0, 0, 0
        TT_SetCrazyArrow(self.tomtomUID, itemName)
        L._debug("Arrow:UpdateArrow", "Successfully set TomTom waypoint. New UID: " .. tostring(self.tomtomUID))
        return true
    end
    self.waypointFailed = true
    L._debug("Arrow:UpdateArrow", "Failed to set TomTom waypoint (TT_AddZWaypoint returned nil). Blocked retries.")
    return false
end

local function BuildArrowScanKey(continent, zoneID, filterMapOn, viewerHash, filters)
    return table.concat({
        tostring(continent),
        tostring(zoneID),
        filterMapOn and "1" or "0",
        tostring(viewerHash or ""),
        tostring(filters.hideAll),
        tostring(filters.hideLooted),
        tostring(filters.hideFaded),
        tostring(filters.hideStale),
        tostring(filters.hideUnconfirmed),
        tostring(filters.hideCollectedME),
        tostring(filters.hideBags),
        tostring(filters.hideLearnedTransmog),
        tostring(filters.minRarity),
        tostring(filters.showWorldforged),
        tostring(filters.showMysticScrolls),
        tostring(filters.showVendors),
        tostring(filters.autoTrackNearest),
    }, "|")
end

-- Zone-scoped GUID set for Filter Map: uses the same Viewer filter predicates
-- as map pins. Do NOT reuse Viewer.Cache.filteredResults — that list is
-- tab-scoped (eq/ms/bmv) and can omit pins that still show on the map.
function Arrow:GetFilterMapZoneGuidSet(zoneID, viewerHash, Viewer)
    local key = tostring(zoneID) .. "|" .. tostring(viewerHash or "")
    if self._fmZoneSet and self._fmZoneKey == key then
        return self._fmZoneSet
    end
    if Viewer and Viewer.ResetFilterMapUncachedCount then Viewer:ResetFilterMapUncachedCount() end
    local set = {}
    local Core = L:GetModule("Core", true)
    local zoneGUIDs = Core and Core.ZoneIndex and Core.ZoneIndex[zoneID]
    local db = L:GetDiscoveriesDB()
    local vendors = L:GetVendorsDB()
    if zoneGUIDs and db then
        for _, guid in ipairs(zoneGUIDs) do
            local d = db[guid] or (vendors and vendors[guid])
            if d and L:DiscoveryPassesFilters(d)
                and Viewer and Viewer.DiscoveryPassesViewerFilters
                and Viewer:DiscoveryPassesViewerFilters(d) then
                set[guid] = true
            end
        end
    end
    self._fmZoneSet = set
    self._fmZoneKey = key
    return set
end

local function IsArrowTargetStillValid(self, d, currentContinent, currentZoneID, autoTrackEnabled, filterMapOn, viewerGuidSet)
    if not d or type(d) ~= "table" or not d.g or not d.xy then return false end
    if self.sessionSkipList[d.g] then return false end
    if d.onHold and not isMine(d) then return false end
    if d.c ~= currentContinent or d.z ~= currentZoneID then return false end
    local targetIz = tonumber(d.iz) or 0
    if not (targetIz == 0 or targetIz == currentZoneID) then return false end
    if autoTrackEnabled and L:IsLootedByChar(d.g) then return false end
    if not L:DiscoveryPassesFilters(d) then return false end
    if filterMapOn then
        if viewerGuidSet then
            if not viewerGuidSet[d.g] then return false end
        else
            local Viewer = L:GetModule("Viewer", true)
            if Viewer and Viewer.DiscoveryPassesViewerFilters and not Viewer:DiscoveryPassesViewerFilters(d) then
                return false
            end
        end
    end
    return true
end

function Arrow:FindBestTarget(px, py, currentContinent, currentZoneID)
    local db = L:GetDiscoveriesDB()
    if not db then self.currentTarget=nil; self._scanKey = nil; return end
    
    local filters = L:GetFilters()
    if filters.hideAll then self.currentTarget=nil; self._scanKey = nil; return end
    
    if not px or not py or not currentContinent or not currentZoneID then
        local spx, spy, sc, sz = self:GetPlayerSnapshot()
        px = px or spx
        py = py or spy
        currentContinent = currentContinent or sc
        currentZoneID = currentZoneID or sz
    end
    if not px or not py then
        L._debug("Arrow:FindBestTarget", "Failed to get player position; keeping current target.")
        return
    end
    local autoTrackEnabled = filters.autoTrackNearest and true or false
    local Viewer = L:GetModule("Viewer", true)
    local filterMapOn = Viewer and Viewer.IsFilterMapEnabled and Viewer:IsFilterMapEnabled()
    local viewerHash = nil
    local viewerGuidSet = nil
    if filterMapOn and Viewer then
        if Viewer.GetFilterStateHash then
            viewerHash = Viewer:GetFilterStateHash()
        end
        viewerGuidSet = self:GetFilterMapZoneGuidSet(currentZoneID, viewerHash, Viewer)
    end

    local scanKey = BuildArrowScanKey(currentContinent, currentZoneID, filterMapOn, viewerHash, filters)
    if self._scanKey == scanKey and self.currentTarget
        and IsArrowTargetStillValid(self, self.currentTarget, currentContinent, currentZoneID, autoTrackEnabled, filterMapOn, viewerGuidSet) then
        return
    end

    local bestTarget, minDist = nil, -1
    local Core = L:GetModule("Core", true)
    local zoneGUIDs = Core and Core.ZoneIndex and Core.ZoneIndex[currentZoneID]
    local vendors = L:GetVendorsDB()

    local function consider(guid, d, skipViewerCheck, skipMapFilterCheck)
        if not d or self.sessionSkipList[guid] then return end
        local targetIz = tonumber(d.iz) or 0
        local isVisibleOnThisMap = (targetIz == 0 or targetIz == currentZoneID)
        if not (isVisibleOnThisMap and d.c == currentContinent and d.z == currentZoneID and d.xy) then
            return
        end
        if not skipMapFilterCheck and not L:DiscoveryPassesFilters(d) then
            return
        end
        if filterMapOn and not skipViewerCheck then
            if viewerGuidSet then
                if not viewerGuidSet[guid] then return end
            elseif Viewer and Viewer.DiscoveryPassesViewerFilters and not Viewer:DiscoveryPassesViewerFilters(d) then
                return
            end
        end
        if autoTrackEnabled and L:IsLootedByChar(guid) then return end
        if d.onHold and not isMine(d) then return end
        local tx, ty = d.xy.x or 0, d.xy.y or 0
        local dx, dy = tx - px, ty - py
        local dist = dx * dx + dy * dy
        if minDist == -1 or dist < minDist then
            minDist = dist
            bestTarget = d
        end
    end

    local usedFastPath = false

    -- Filter Map ON: zone GUID set built with DiscoveryPassesViewerFilters
    -- (same rules as map pins; not the Viewer tab list).
    if filterMapOn and viewerGuidSet and zoneGUIDs then
        usedFastPath = true
        for _, guid in ipairs(zoneGUIDs) do
            if viewerGuidSet[guid] then
                local d = db[guid] or (vendors and vendors[guid])
                if d then consider(guid, d, true, false) end
            end
        end
    end

    -- Filter Map OFF: reuse Map minimap filtered cache when warm (empty is valid).
    if not usedFastPath and not filterMapOn then
        local Map = L:GetModule("Map", true)
        if Map and Map.cachingEnabled and not Map.cacheIsDirty and Map.cachedVisibleDiscoveries then
            usedFastPath = true
            for _, d in ipairs(Map.cachedVisibleDiscoveries) do
                if d and d.g then
                    consider(d.g, d, true, true)
                end
            end
        end
    end

    if not usedFastPath then
        if zoneGUIDs then
            for _, guid in ipairs(zoneGUIDs) do
                local d = db[guid] or (vendors and vendors[guid])
                if d then consider(guid, d, false, false) end
            end
        else
            for guid, d in pairs(db) do
                consider(guid, d, false, false)
            end
            if vendors then
                for guid, d in pairs(vendors) do
                    consider(guid, d, false, false)
                end
            end
        end
    end

    if not bestTarget and self.currentTarget and self.currentTarget.g
        and not self.sessionSkipList[self.currentTarget.g]
        and not L:IsLootedByChar(self.currentTarget.g) then
        -- Zone/subzone flap: keep the live waypoint instead of clearing.
        -- Never sticky-keep a looted pin (auto-track off used to).
        return
    end

    self.currentTarget = bestTarget
    self._scanKey = scanKey
end

function Arrow:UpdateArrow(forceUpdate)
    if not self.enabled or not IsTomTomAvailable() then return end

    if DropDownList1 and DropDownList1:IsShown() then 
        return 
    end

    local player_x, player_y, playerC, playerZ = self:GetPlayerSnapshot()
    if not player_x or not player_y then
        L._debug("Arrow:UpdateArrow", "Could not get player position this frame. Aborting update.")
        return
    end

    local oldTargetGUID = self.currentTarget and self.currentTarget.g
    local targetThisUpdate
    
    if self.manualTarget then
        targetThisUpdate = self.manualTarget
    else
        if forceUpdate then
            self._scanKey = nil
        end
        self:FindBestTarget(player_x, player_y, playerC, playerZ)
        targetThisUpdate = self.currentTarget
    end
    
    self.currentTarget = targetThisUpdate
    local newTargetGUID = targetThisUpdate and targetThisUpdate.g

    if not newTargetGUID then
        -- Empty on purpose (hideAll, skipped last pin). Zone flaps keep
        -- currentTarget via FindBestTarget sticky, so they do not land here.
        if self.tomtomUID then
            self:ClearTomTomWaypoint()
        end
        self:UpdateSkipBar()
        return
    end

    -- Recreate when the GUID changes, UID is missing, or the user explicitly
    -- Navigate/Skip/Clear (forceUpdate). Same-UID SetCrazyArrow on an arrived
    -- pin only flashes one frame then TomTom hides it again.
    if forceUpdate or newTargetGUID ~= oldTargetGUID or not self.tomtomUID then
        if forceUpdate then self.waypointFailed = nil end
        L._debug("Arrow:UpdateArrow", "Target changed or forced. Old: " .. tostring(oldTargetGUID) .. " New: " .. tostring(newTargetGUID))
        self:ClearTomTomWaypoint()
        self:ApplyTomTomWaypoint(self.currentTarget)
        self:SnapshotTrackedBagCount(self.currentTarget)
        self._deadUidTicks = 0
    else
        -- Keep the same pin. Recreate only if TomTom deleted the waypoint.
        -- Hide is swallowed while we own it (HookCrazyArrowKeepAlive).
        local crazy = _G.TomTomCrazyArrow
        local uidDead = _G.TomTom and _G.TomTom.IsValidWaypoint
            and not _G.TomTom:IsValidWaypoint(self.tomtomUID)
        if uidDead then
            self._deadUidTicks = (self._deadUidTicks or 0) + 1
            if self._deadUidTicks >= 2 then
                self._deadUidTicks = 0
                self:ClearTomTomWaypoint()
                self:ApplyTomTomWaypoint(self.currentTarget)
            end
        else
            self._deadUidTicks = 0
            if crazy and not crazy:IsShown() then
                TT_SetCrazyArrow(self.tomtomUID, WaypointTitle(self.currentTarget))
            end
        end
    end

    if self.manualTarget or self.currentTarget then
        self:RememberTrackedTarget(self.manualTarget or self.currentTarget)
    end
    self:UpdateSkipBar()
end

function Arrow:ClearTarget()
    self:ClearTomTomWaypoint()
    self.currentTarget = nil
    self.manualTarget = nil
    self.lastTrackedTarget = nil
    self._ttMissingTicks = 0
    if self.skipBar then self.skipBar:Hide() end
end

function Arrow:CanNavigateRecord(rec)
    if not rec then
        return false
    end
    
    if rec.onHold and not isMine(rec) then
        return false
    end

    if not (rec.xy and rec.xy.x and rec.xy.y) then
        return false
    end
    
    
    local iz = tonumber(rec.iz) or 0
    if iz > 0 then
        local _, currentMapID = self:GetPlayerLocation()
        if tonumber(currentMapID) ~= iz then
            print("|cffff7f00LootCollector:|r Cannot auto-navigate. This discovery is inside an instance.")
            return false
        end
    end
    
    return true
end

local function resolveZoneName(rec)
    local c  = tonumber(rec.c) or 0
    local z  = tonumber(rec.z) or 0
    local iz = tonumber(rec.iz) or 0
    return L.ResolveZoneDisplay(c, z, iz)
end

function Arrow:PointToRecordV5(rec)
    L._debug("Arrow", "PointToRecordV5() called.")
    if not self or not self.CanNavigateRecord then return false end
    if not self:CanNavigateRecord(rec) then
        if rec and rec.g and self.currentTarget and self.currentTarget.g == rec.g then
            L._debug("Arrow", "PointToRecordV5 -> clearing target because it's now invalid/on hold.")
            if self.ClearTarget then
                self:ClearTarget()
            else
                self.enabled = false
            end
        end
        return false
    end
    
    L._debug("PointToRecordV5", " rec.z="..tostring(rec.z)..", rec.c="..tostring(rec.c).." rec.iz="..tostring(rec.iz)..", resolveZoneName="..resolveZoneName(rec))
    
    self.manualTarget = {
        g     = rec.g,
        i     = rec.i,
        il    = rec.il,
        xy    = rec.xy,
        c     = rec.c,
        z     = rec.z,
        iz    = tonumber(rec.iz) or 0,
        label = resolveZoneName(rec),
    }

    if rec.g then
        self.sessionSkipList[rec.g] = nil
    end

    self.enabled = true
    self:RememberTrackedTarget(self.manualTarget)
    self:SnapshotTrackedBagCount(self.manualTarget)

    if self.UpdateArrow then
        self:UpdateArrow(true)
        
        if self.StartUpdates then
            self:StartUpdates()
        end
        return true
    end

    return false
end

function Arrow:ClearIfOnHold(rec)
    if not rec or not rec.g then return end
    if not self or not self.currentTarget or self.currentTarget.g ~= rec.g then
        return
    end
    if rec.onHold and not isMine(rec) then
        if self.ClearTarget then
            self:ClearTarget()
        else
            self.enabled = false
            self.currentTarget = nil
        end
    end
end

return Arrow
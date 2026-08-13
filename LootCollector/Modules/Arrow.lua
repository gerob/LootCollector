local L = LootCollector
local Arrow = L:NewModule("Arrow", "AceEvent-3.0")

local UPDATE_INTERVAL = 2.0
local ARRIVAL_DISTANCE_YARDS = 15 
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

local function TT_AddZWaypoint(c, z, x, y, desc)
    if not IsTomTomAvailable() then return end
    x, y = (x or 0) * 100, (y or 0) * 100
    if _G.TomTom and _G.TomTom.AddZWaypoint then return TomTom:AddZWaypoint(c, z, x, y, desc, false, false, true, nil, true, false)
    elseif _G.TomTomAddZWaypoint then return TomTomAddZWaypoint(c, z, x, y, desc, false, false, true, nil, true, false) end
end

local function TT_RemoveWaypoint(uid)
    if not uid or not IsTomTomAvailable() then return end
    if _G.TomTom and _G.TomTom.RemoveWaypoint then TomTom:RemoveWaypoint(uid)
    elseif _G.TomTomRemoveWaypoint then TomTomRemoveWaypoint(uid) end
end

local function TT_SetCrazyArrow(uid, title)
    if not IsTomTomAvailable() then return end
    if _G.TomTom and _G.TomTom.SetCrazyArrow then TomTom:SetCrazyArrow(uid, ARRIVAL_DISTANCE_YARDS, title)
    elseif _G.TomTomSetCrazyArrow then TomTomSetCrazyArrow(uid, ARRIVAL_DISTANCE_YARDS, title) end
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

local function SaveMapState() 
    return GetCurrentMapContinent and GetCurrentMapContinent() or 0, 
           GetCurrentMapZone and GetCurrentMapZone() or 0, 
           GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0 
end

local function RestoreMapState(c,z,dl) 
    if SetMapZoom and c and z then SetMapZoom(c,z) end
    if SetDungeonMapLevel and dl then SetDungeonMapLevel(dl) end 
end

function Arrow:GetPlayerPos()
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        return GetPlayerMapPosition("player")
    else
        local sc,sz,sdl = SaveMapState()
        if SetMapToCurrentZone then SetMapToCurrentZone() end 
        local px,py = GetPlayerMapPosition("player")
        RestoreMapState(sc,sz,sdl) 
        return px, py
    end
end

function Arrow:GetPlayerLocation()
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        return GetCurrentMapContinent(), GetCurrentMapAreaID()
    else
        local sc, sz, sdl = SaveMapState()
        if SetMapToCurrentZone then SetMapToCurrentZone() end 
        local c = GetCurrentMapContinent and GetCurrentMapContinent() or 0
        local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
        RestoreMapState(sc,sz,sdl) 
        return c, mapID
    end
end

function Arrow:ClearSessionSkipList()
    wipe(self.sessionSkipList)
    print("|cff00ff00LootCollector:|r Session skip list has been cleared.")
    self:UpdateArrow(true) 
end

function Arrow:SkipNearest()
    if self.enabled and self.currentTarget and not self.manualTarget then
        local guid = self.currentTarget.g
        if guid then
            self.sessionSkipList[guid] = true            
            print(string.format("|cff00ff00LootCollector:|r Skipped tracking of: %s", self.currentTarget.il or "discovery"))
            self:UpdateArrow(true) 
        end
    else
        print("|cffff7f00LootCollector:|r No active target to skip.")
    end
end

local function IsAutoTrackEnabled()
    local f = L.GetFilters and L:GetFilters()
    if f then return f.autoTrackNearest and true or false end
    return L.db and L.db.char and L.db.char.mapFilters and L.db.char.mapFilters.autoTrackNearest and true or false
end

function Arrow:OnPlayerLootedItem(event, itemID, c, z, x, y)
    L._debug("Arrow", "OnPlayerLootedItem() event received.")
    
    if not IsAutoTrackEnabled() then
        L._debug("Arrow", "-> OnPlayerLootedItem ignored, auto-tracking is disabled.")
        return 
    end
    if not self.enabled or not self.currentTarget then return end

    local target = self.currentTarget
    
    if target.i == itemID and target.c == c and target.z == z then
        local dist = L:ComputeDistance(target.c, target.z, target.xy.x, target.xy.y, c, z, x, y)
        local Constants = L:GetModule("Constants", true)
        
        local CLUSTER_YARDS = 40
        if Constants then
            if target.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL then CLUSTER_YARDS = Constants.CLUSTER_YARDS_MS or 200
            elseif target.dt == Constants.DISCOVERY_TYPE.BLACKMARKET then CLUSTER_YARDS = Constants.CLUSTER_YARDS_VEND or 20
            else CLUSTER_YARDS = Constants.CLUSTER_YARDS_WF or 100 end
        end
        
        if dist and dist <= CLUSTER_YARDS then            
            L._debug("Arrow", "Player looted current auto-tracked target: " .. tostring(target.g))
            
            if target.g then
                self.sessionSkipList[target.g] = true
            end

            self.manualTarget = nil 
            self:UpdateArrow(true) 
        end
    end
end

function Arrow:OnPlayerLogin()
    L._debug("Arrow", "OnPlayerLogin() event received.")
    if IsAutoTrackEnabled() then
        self:Show()
    end
end

function Arrow:OnInitialize()
    if L.LEGACY_MODE_ACTIVE then return end
    self:RegisterMessage("LOOTCOLLECTOR_PLAYER_LOOTED_ITEM", "OnPlayerLootedItem")
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
end

function Arrow:StartUpdates() 
    L._debug("Arrow", "StartUpdates() called.")
    
    
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
    self:RememberTrackedTarget(discovery)
    self:UpdateArrow(true)
    self:StartUpdates()
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
    if self.tomtomUID then 
        
        L._debug("Arrow", "ClearTomTomWaypoint() called. Current TomTom UID: " .. tostring(self.tomtomUID))
        TT_RemoveWaypoint(self.tomtomUID)
        self.tomtomUID=nil
        TT_ClearCrazyArrow() 
    end 
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

function Arrow:FindBestTarget()
    local db = L:GetDiscoveriesDB()
    if not db then self.currentTarget=nil; self._scanKey = nil; return end
    
    local filters = L:GetFilters()
    if filters.hideAll then self.currentTarget=nil; self._scanKey = nil; return end
    
    local px,py=self:GetPlayerPos()
    if not px or not py then 
        L._debug("Arrow:FindBestTarget", "Failed to get player position, cannot find best target.")
        self.currentTarget=nil
        return 
    end

    local currentContinent, currentZoneID = self:GetPlayerLocation()
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

    self.currentTarget = bestTarget
    self._scanKey = scanKey
end

function Arrow:UpdateArrow(forceUpdate)
    if not self.enabled or not IsTomTomAvailable() then return end

    if DropDownList1 and DropDownList1:IsShown() then 
        return 
    end

    local player_x, player_y = self:GetPlayerPos()
    if not player_x or not player_y then
        L._debug("Arrow:UpdateArrow", "Could not get player position this frame. Aborting update.")
        return
    end

    if self.manualTarget and self.tomtomUID then
        local dist = TT_GetDistanceToWaypoint(self.tomtomUID)
        if dist and dist < ARRIVAL_DISTANCE_YARDS then
            print("|cff00ff00LootCollector:|r Arrived at manual destination. Switching to auto-navigation.")
            local arrivedGuid = self.manualTarget.g
            if arrivedGuid then
                self.sessionSkipList[arrivedGuid] = true
            end
            self.manualTarget = nil
            self:ClearTomTomWaypoint()
            forceUpdate = true 
        end
    end

    local oldTargetGUID = self.currentTarget and self.currentTarget.g
    local targetThisUpdate
    
    if self.manualTarget then
        targetThisUpdate = self.manualTarget
    else
        if forceUpdate then
            self._scanKey = nil
        end
        self:FindBestTarget()
        targetThisUpdate = self.currentTarget
    end

    local autoTrackMode = IsAutoTrackEnabled()
    if autoTrackMode and not self.manualTarget and targetThisUpdate then
        local currentC, currentZ = self:GetPlayerLocation()
        if currentC and currentZ then
            local dist = L:ComputeDistance(targetThisUpdate.c, targetThisUpdate.z, targetThisUpdate.xy.x, targetThisUpdate.xy.y, currentC, currentZ, player_x, player_y)
            
            if dist and dist <= ARRIVAL_DISTANCE_YARDS then
                L._debug("Arrow:UpdateArrow", "Auto-track target is very close, clearing waypoint to prevent clutter.")
                if targetThisUpdate.g then
                    self.sessionSkipList[targetThisUpdate.g] = true
                end
                self:ClearTomTomWaypoint()
                self.currentTarget = nil
                self._scanKey = nil
                -- Pick the next-nearest target instead of leaving the arrow blank.
                self:FindBestTarget()
                targetThisUpdate = self.currentTarget
            end
        end
    end
    
    self.currentTarget = targetThisUpdate
    local newTargetGUID = targetThisUpdate and targetThisUpdate.g

    local needsReapply = false

    if forceUpdate then
        needsReapply = true
    elseif newTargetGUID ~= oldTargetGUID then
        needsReapply = true
        self.waypointFailed = nil 
    elseif not self.tomtomUID and newTargetGUID and not self.waypointFailed then
        needsReapply = true
    elseif self.tomtomUID then
        -- TomTom can report a just-created (or map-changed) waypoint as invalid.
        -- Re-apply a couple of times while enabled; do not Hide() (that broke /lcarrow
        -- toggle-on). Use /lcarrow to dismiss intentionally.
        if _G.TomTom and _G.TomTom.IsValidWaypoint and not _G.TomTom:IsValidWaypoint(self.tomtomUID) then
            self._invalidWaypointTicks = (self._invalidWaypointTicks or 0) + 1
            L._debug("Arrow:UpdateArrow", "TomTom waypoint invalid (tick " .. self._invalidWaypointTicks .. ").")
            -- ClearTomTomWaypoint removes via UID then nils; do not nil first or the pin is orphaned.
            self:ClearTomTomWaypoint()
            if self._invalidWaypointTicks <= 2 then
                needsReapply = true
            else
                self.waypointFailed = true
            end
        else
            self._invalidWaypointTicks = 0
            local ttDist = TT_GetDistanceToWaypoint(self.tomtomUID)
            if not ttDist then
                self._ttMissingTicks = (self._ttMissingTicks or 0) + 1
                if self._ttMissingTicks > 3 then
                    L._debug("Arrow:Resurrection", "CRITICAL: Astrolabe glitch confirmed. Forcefully resurrecting the TomTom waypoint!")
                    needsReapply = true
                    self._ttMissingTicks = 0
                end
            else
                self._ttMissingTicks = 0
            end
        end
    end

    if not newTargetGUID then
        if self.tomtomUID then
            self:ClearTomTomWaypoint()
        end
        return
    end

    if needsReapply then
        L._debug("Arrow:UpdateArrow", "Target changed, forced update, or resurrected. Old: " .. tostring(oldTargetGUID) .. " New: " .. tostring(newTargetGUID))
        self:ClearTomTomWaypoint()

        local d = self.currentTarget
        local mapC = d.c
        local mapZ_areaID = d.z 
        local x = d.xy and d.xy.x or 0
        local y = d.xy and d.xy.y or 0
        local itemName = (d.il and d.il:match("%[(.+)%]")) or "Discovery"

        local userC, userZ, userDL = SaveMapState()
        
        if SetMapByID then SetMapByID(mapZ_areaID - 1) end
        
        L._debug("Arrow", string.format("Sending waypoint to TomTom. Continent: %s, AreaID: %s", tostring(mapC), tostring(mapZ_areaID)))
        self.tomtomUID = TT_AddZWaypoint(mapC, mapZ_areaID, x, y, itemName)
        
        if userC and userZ then
            RestoreMapState(userC, userZ, userDL)
        end
        
        if self.tomtomUID then 
            self.waypointFailed = nil
            self._invalidWaypointTicks = 0
            TT_SetCrazyArrow(self.tomtomUID, itemName) 
            L._debug("Arrow:UpdateArrow", "Successfully set TomTom waypoint. New UID: " .. tostring(self.tomtomUID))
        else
            self.waypointFailed = true 
            L._debug("Arrow:UpdateArrow", "Failed to set TomTom waypoint (TT_AddZWaypoint returned nil). Blocked retries.")
        end
    end

    if self.manualTarget or self.currentTarget then
        self:RememberTrackedTarget(self.manualTarget or self.currentTarget)
    end
end

function Arrow:ClearTarget()
    self:ClearTomTomWaypoint()
    self.currentTarget = nil
    self.manualTarget = nil
    self.lastTrackedTarget = nil
    self._ttMissingTicks = 0 
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

    self.enabled = true
    self:RememberTrackedTarget(self.manualTarget)

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
local AceAddon     = LibStub("AceAddon-3.0")
local AceEvent     = LibStub("AceEvent-3.0")
local AceComm      = LibStub("AceComm-3.0")
local AceDB        = LibStub("AceDB-3.0")

local LootCollector = AceAddon:NewAddon("LootCollector", "AceEvent-3.0", "AceComm-3.0")
_G.LootCollector = LootCollector

BINDING_HEADER_LOOTCOLLECTOR = GetAddOnMetadata(..., "Title")
LootCollector.LEGACY_MODE_ACTIVE = true
LootCollector.addonPrefix = "BBLC25AM"
LootCollector.chatChannel = "BBLC25C"
LootCollector.DEBUG_MODE = false

-- PERF: profiler now defaults OFF. It wraps nearly every function in the
-- comm/core hot path (two debugprofilestop() calls plus stats bookkeeping
-- per invocation, 10-14 profiled calls per incoming channel message), which
-- is a constant tax at 5-11k msgs/minute. Toggle at runtime: /lcprofiler on
LootCollector._profilerEnabled = false
LootCollector._profilerStats = {}
LootCollector._normalizedNameCache = {}

if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(86400, function()
        if LootCollector._profilerStats then
            wipe(LootCollector._profilerStats)
        end
    end)
end

function LootCollector:ProfileStart()
    if not self._profilerEnabled then return nil end
    return debugprofilestop()
end

function LootCollector:ProfileStop(funcName, startTime)
    if not startTime then return end
    local elapsed = debugprofilestop() - startTime
    
    local stats = self._profilerStats[funcName]
    if not stats then
        stats = { 
            calls = 0, total = 0, max = 0, min = 999999, 
            
            b3 = 0, b5 = 0, b10 = 0, b20 = 0, b50 = 0 
        }
        self._profilerStats[funcName] = stats
    end
    
    stats.calls = stats.calls + 1
    stats.total = stats.total + elapsed
    
    if elapsed > stats.max then stats.max = elapsed end
    if elapsed < stats.min then stats.min = elapsed end
    
    
    if elapsed >= 50.0 then
        stats.b50 = stats.b50 + 1
    elseif elapsed >= 20.0 then
        stats.b20 = stats.b20 + 1
    elseif elapsed >= 10.0 then
        stats.b10 = stats.b10 + 1
    elseif elapsed >= 5.0 then
        stats.b5 = stats.b5 + 1
    elseif elapsed >= 3.0 then
        stats.b3 = stats.b3 + 1
    end
end

LootCollector.ignoreList = {
    ["Embossed Mystic Scroll"] = true,
    ["Unimbued Mystic Scroll"] = true,
    ["Untapped Mystic Scroll"] = true,
    ["Felforged Mystic Scroll: Unlock Uncommon"] = true,
    ["Felforged Mystic Scroll: Unlock Rare"] = true,
    ["Felforged Mystic Scroll: Unlock Legendary"] = true,
    ["Felforged Mystic Scroll: Unlock Epic"] = true,
    ["Enigmatic Mystic Scroll"] = true,
    ["Friendly Sludgemonster"] = true,
    ["Worldforged Key Fragment"] = true,
    ["Worldforged Key"] = true,	
}

LootCollector.sourceSpecificIgnoreList = {
    ["Mystic Scroll: White Walker"] = true,
    ["Mystic Scroll: Powder Mage"] = true,
    ["Mystic Scroll: Midnight Flames"] = true,
    ["Mystic Scroll: Lucifur"] = true,
    ["Mystic Scroll: Knight of the Eclipse"] = true,
    ["Mystic Scroll: Hoplite"] = true,
    ["Mystic Scroll: Fire Watch"] = true,
    ["Mystic Scroll: Eskimo"] = true,
    ["Mystic Scroll: Dark Surgeon"] = true,
    ["Mystic Scroll: Cauterizing Fire"] = true,
    ["Mystic Scroll: Blood Venom"] = true,
    ["Mystic Scroll: Ancestral Ninja"] = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_SHOW_DISCOVERY_REQUEST"] = {
    text = "|cffffff00%s|r wants to show you a discovery on the map for:\n%s",
    button1 = "Allow",
    button2 = "Ignore Session",
    button3 = "Block Permanently",
    OnAccept = function(self, data)
      if not data then return end
      
      local Core = LootCollector:GetModule("Core", true)
      local finalGuid = nil
      if Core and Core.AddDiscovery then
        finalGuid = Core:AddDiscovery(data, { isNetwork = false, op = "SHOW", suppressToast = true })
      end
      
      if finalGuid then
          local Map = LootCollector:GetModule("Map", true)
          if Map and Map.FocusOnDiscovery then
              Map:FocusOnDiscovery(finalGuid)
          end
      end
    end,
    OnCancel = function(self, data, reason)
        if reason == "clicked" and data and data.sender then
            LootCollector.sessionIgnoredShowRequests = LootCollector.sessionIgnoredShowRequests or {}
            LootCollector.sessionIgnoredShowRequests[data.sender] = true
            print(string.format("|cffff7f00LootCollector:|r Ignoring map show requests from %s for this session.", data.sender))
        end
    end,
    OnAlt = function(self, data)
      if not (data and data.sender) then return end
      local sender = data.sender
      if LootCollector.db and LootCollector.db.profile and LootCollector.db.profile.sharing then
        LootCollector.db.profile.sharing.blockList = LootCollector.db.profile.sharing.blockList or {}
        LootCollector.db.profile.sharing.blockList[sender] = true
        LootCollector.sessionIgnoredShowRequests = LootCollector.sessionIgnoredShowRequests or {}
        LootCollector.sessionIgnoredShowRequests[sender] = true
        print(string.format("|cffff0000LootCollector:|r Player |cffffff00%s|r has been added to your block list.", sender))
      end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }

StaticPopupDialogs["LOOTCOLLECTOR_OPTIONAL_DB_UPDATE"] = {
  text = "LootCollector has detected a starter database (version %s).\n\n%s\n\nWould you like to merge it with your existing data?",
  button1 = "Yes, Merge",
  button2 = "No, Thanks",
  OnAccept = function(self, data)
    local dbData = _G.LootCollector_OptionalDB_Data
    if not (dbData and dbData.data) then return end
    local ImportExport = LootCollector:GetModule("ImportExport", true)
    if ImportExport and ImportExport.ApplyImportString then
        ImportExport:ApplyImportString(dbData.data, "MERGE", false)
    end
    if LootCollector.db and LootCollector.db.profile and data then
        LootCollector.db.profile.offeredOptionalDB = data
    end
  end,
  OnCancel = function(self, data, reason)
    if LootCollector.db and LootCollector.db.profile and data then
        LootCollector.db.profile.offeredOptionalDB = data
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

StaticPopupDialogs["LOOTCOLLECTOR_PRESTIGE_CLEAR_LOOTED"] = {
  text = "Your level dropped from %s to %s.\n\nThis usually means you prestiged, or you made a new character with the same name (Hardcore).\n\nClear looted marks for |cff00ff00this character|r so Worldforged pins are not still greyed out?\n\n|cffaaaaaaBackup and archive are kept. Do not Merge Looted Backup unless you want the old greys back.|r",
  button1 = "Yes, Clear Looted",
  button2 = "Keep Looted Marks",
  OnAccept = function(self, data)
    if LootCollector.ClearLiveLootedHistory then
      LootCollector:ClearLiveLootedHistory()
    end
    if data and data.afterLevel then
      LootCollector:RememberPlayerLevel(data.afterLevel)
    end
  end,
  OnCancel = function(self, data)
    if data and data.afterLevel then
      LootCollector:RememberPlayerLevel(data.afterLevel)
    end
  end,
  OnHide = function(self)
    local data = self.data
    if data and data.afterLevel then
      LootCollector:RememberPlayerLevel(data.afterLevel)
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  showAlert = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_WELCOME"] = {
  text = "|cffffff00LootCollector quick start|r\n\n" ..
    "• Open Discoveries: minimap button or |cffffffff/lcv|r\n" ..
    "• Filter Map: apply your Discoveries filters to map/minimap pins\n" ..
    "• Sync: public channel is on by default. The shield pauses it above 5000 msgs/min. Change under |cffffffff/lc|r → Behavior & Sharing → Sharing Controls\n" ..
    "• Empty Discoveries? Merge Starter Database (Import/Export), or use the button on the empty list\n\n" ..
    "Re-enable this tip anytime: |cffffffff/lc|r → Behavior & Sharing → Show welcome tips on login.",
  button1 = "Got it",
  hasCheckBox = true,
  OnShow = function(self)
    if self.CheckBox then
      self.CheckBox:SetText("Don't show this again")
      self.CheckBox:SetChecked(true)
      self.CheckBox:Show()
    end
  end,
  OnAccept = function(self)
    local hide = true
    if self.CheckBox then
      hide = self.CheckBox:GetChecked() and true or false
    end
    if hide and LootCollector.db and LootCollector.db.profile then
      LootCollector.db.profile.hideLootCollectorWelcome = true
    end
  end,
  OnHide = function(self)
    if self.CheckBox then
      self.CheckBox:SetChecked(false)
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

StaticPopupDialogs["LOOTCOLLECTOR_PUBLIC_CHANNEL_PROMPT"] = {
  text = "|cffffff00LootCollector: Public Channel Sync|r\n\n" ..
    "Your public channel sync is off, so pins only update from what you find locally (or party/guild/whisper/import).\n\n" ..
    "Turn it on to receive confirms, coordinate fixes, and fade/stale votes from other players. The Auto-Pause Shield leaves the channel if traffic exceeds 5000 msgs/min, then rejoins after 5 minutes.\n\n" ..
    "You can change this later: |cffffffff/lc|r → Behavior & Sharing → Sharing Controls.",
  button1 = "Enable Sync",
  button2 = "Not now",
  OnAccept = function()
    local p = LootCollector.db and LootCollector.db.profile
    if not p then return end
    p.sharing = p.sharing or {}
    p.sharing.publicChannelEnabled = true
    p.sharing.autoPauseEnabled = true
    p.sharing.autoPauseThreshold = 5000
    p.promptedPublicChannelSync = true
    local Comm = LootCollector:GetModule("Comm", true)
    if Comm and LootCollector.channelReady and Comm.EnsureChannelJoined then
      Comm:EnsureChannelJoined()
    end
    print("|cff00ff00LootCollector:|r Public channel sync enabled. Shield threshold is 5000 msgs/min.")
  end,
  OnCancel = function()
    if LootCollector.db and LootCollector.db.profile then
      LootCollector.db.profile.promptedPublicChannelSync = true
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

local meCollectedCache = {}
local meCollectedCacheTime = {}
local ME_COLLECTED_CACHE_DURATION = 240

local dbDefaults = {
    profile = {
        enabled = true,
        paused = false,
        offeredOptionalDB = nil,
        hideLootCollectorWelcome = false,
        minQuality = 2,
        favorites = {},
        perCharacterFavorites = false,
	    checkOnlySingleItemLoot = true,
	    enhancedWFTooltip = true,
        mapFilters = { 
            hideAll = false, 
            hideFaded = false, 
            hideStale = false, 
            hideLooted = true,
            hideUncached = false,
            hideUnconfirmed = false,
            hideLearnedTransmog = false,
            hideCollectedME = false,
		    hideBags = false,
	        hidePlayerNames = false,
			hideNonEssential = true,
            disableFadeEffect = true,
            pinSize = 15, 
            minimapPinSize = 15, 
            showZoneSummaries = false,
            showMinimap = true,
            autoTrackNearest = false,
            maxMinimapDistance = 500,
            showMysticScrolls = true,
            showWorldforged = true,
            showVendors = true,
            minRarity = 0,
            usableByClasses = {},
            allowedEquipLoc = {},
            applyViewerFiltersOnMap = false,
			enableChatLinkIntegration = true,
			disableProximityList = true,
			filterButtonLocked = true,
			filterButtonDragged = false,
        },
        toasts = { 
            enabled = true,            
            displayTime = 5.0,
            tickerEnabled = true,
            tickerSpeed = 90,
            tickerFontDelta = 3,
            tickerOutline = false,
            whiteFrame = true,
        },
        sharing = { 
            enabled = true, 
            anonymous = false, 
            delayed = false,
            delaySeconds = 20,
            allowShowRequests = true,
            rejectPartySync = false,
            rejectGuildSync = false,
            rejectWhisperSync = false,
            ackOnChannel = true,
            publicChannelEnabled = true,
            autoPauseEnabled = true,
            autoPauseThreshold = 5000,
            blockList = {},
            whiteList = {},
        },
	  viewer = {
        rowFont = "Fonts\\ARIALN.TTF",
        rowFontSize = 14,
        rowHeight = 28,
        uiFont = "Fonts\\ARIALN.TTF",
        uiFontSize = 13,
        useWCAGColoring = true,
        inlineVendorView = false,
        splitRatio = 0.64,
        asyncLoading = true,
        worldforgedPhase = 0,
        -- false = Discoveries stays open when the world map opens (M)
        closeOnWorldMap = false,
        
        width = 1150,
        height = 674,
        point = "CENTER",
        x = 0,
        y = 0,
        scale = 1.0,
        },
        filterPresets = {},
        viewerLiveFilters = false,
        lastVersionToastAt = 0,
        promptedPublicChannelSync = false,
        ignoreZones = {},
        decay = { fadeAfterDays = 30, staleAfterDays = 90, removeAfterDays = 120, },
	    debugMode = false,
	    mdebugMode = false,
	    idebugMode = false,
	    cdebugMode = false,
	    vdebugMode = false,
        discoveries = {},
    },
    char = { 
        looted = {},
        lootedBackup = {},
        hidden = {},
        favorites = {},
        paused = false,      
        autoPauseInBG = true,
        autoPauseInRaidInstance = true,
        autoPauseInRaidGroup = true,
        lastSeenLevel = nil,
    },
    global = { 
        realms = {}, 
        cacheQueue = {},
        autoCleanupPhase = 0,
        manualCleanupRunCount = 0,
        purgeEmbossedState = 0,
        -- Append-only per-character looted safety net (survives Clear All / char wipe).
        lootedArchive = {},
        -- High-water mark for sudden-drop detection on login.
        lootedHighWater = {},
        coordAuthorityRevision = 0,
    },
}

LootCollector.shadingModeActive = false

function LootCollector._debug(module, message)
    local debugMode = false
    if LootCollector.db and LootCollector.db.profile then
        debugMode = LootCollector.db.profile.debugMode
    elseif _G.LootCollectorDB_Asc and _G.LootCollectorDB_Asc.profiles and _G.LootCollectorDB_Asc.profiles.Default then
        debugMode = _G.LootCollectorDB_Asc.profiles.Default.debugMode
    end

    if debugMode then
        print(string.format("|cffffff00[LC-Debug|cffff8c00][%s]|r %s", tostring(module), tostring(message)))
    end
end

function LootCollector._mdebug(module, message)
    if LootCollector.db and LootCollector.db.profile and LootCollector.db.profile.mdebugMode then
        print(string.format("|cffffff00[LC-MapDebug|cffff8c00][%s]|r %s", tostring(module), tostring(message)))
    end
end

function LootCollector._idebug(module, message)
    if LootCollector.db and LootCollector.db.profile and LootCollector.db.profile.idebugMode then
        print(string.format("|cffffff00[LC-Debug|cffff8c00][%s]|r %s", tostring(module), tostring(message)))
    end
end

function LootCollector._ddebug(module, message)
    if LootCollector.DEBUG_MODE then
        print(string.format("|cffffff00[LC-DetectDebug|cffff8c00][%s]|r %s", tostring(module), tostring(message)))
    end
end

function LootCollector._cdebug(module, message)
    if LootCollector.db and LootCollector.db.profile and LootCollector.db.profile.cdebugMode then
        print(string.format("|cffffff00[LC-ChatDebug|cffff8c00][%s]|r %s", tostring(module), tostring(message)))
    end
end
    
LootCollector._normalizedNameCache = {}
function LootCollector:normalizeSenderName(sender)
    if type(sender) ~= "string" then return nil end
    
    local cached = self._normalizedNameCache[sender]
    if cached ~= nil then 
        return cached == false and nil or cached 
    end
    
    local name = sender:match("([^%-]+)") or sender
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    
    if name == "" then
        self._normalizedNameCache[sender] = false
        return nil
    end
    
    self._normalizedNameCache[sender] = name
    return name
end

function LootCollector:Round2(v)
    v = tonumber(v) or 0
    return math.floor(v * 100 + 0.5) / 100
end

function LootCollector:Round4(v)
    v = tonumber(v) or 0
    return math.floor(v * 10000 + 0.5) / 10000
end

function LootCollector:GenerateGUID(c, z, iz, i, x, y)
    local x4 = self:Round4(x or 0)
    local y4 = self:Round4(y or 0)
    return tostring(c or 0) .. "-" .. tostring(z or 0) .. "-" .. tostring(iz or 0) .. "-" .. tostring(i or 0) .. "-" .. string.format("%.4f", x4) .. "-" .. string.format("%.4f", y4)
end

function LootCollector:GenerateVendorGUID(vendorType, c, z, iz, x, y)
    local x4 = self:Round4(x or 0)
    local y4 = self:Round4(y or 0)
    return tostring(vendorType or "V") .. "-" .. tostring(c or 0) .. "-" .. tostring(z or 0) .. "-" .. tostring(iz or 0) .. "-" .. string.format("%.4f", x4) .. "-" .. string.format("%.4f", y4)
end

function LootCollector:ComputeDistance(c1, z1, x1, y1, c2, z2, x2, y2)
    local pTime = self.ProfileStart and self:ProfileStart() 

    c1 = tonumber(c1) or 0
    z1 = tonumber(z1) or 0
    x1 = tonumber(x1) or 0
    y1 = tonumber(y1) or 0
    
    c2 = tonumber(c2) or 0
    z2 = tonumber(z2) or 0
    x2 = tonumber(x2) or 0
    y2 = tonumber(y2) or 0
    
    if c1 ~= c2 then 
        if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
        return nil 
    end 

    if z1 == z2 then
        local Map = self:GetModule("Map", true)
        local zoneData = Map and Map.WorldMapSize and Map.WorldMapSize[c1] and Map.WorldMapSize[c1][z1]
        if zoneData then
            local xDelta = (x2 - x1) * zoneData.width
            local yDelta = (y2 - y1) * zoneData.height
            local dist = math.sqrt(xDelta*xDelta + yDelta*yDelta)
            if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
            return dist, xDelta, yDelta
        end
    end

    if C_WorldMap and type(C_WorldMap.GetWorldPosition) == "function" then
        local wx1, wy1 = C_WorldMap.GetWorldPosition(z1, x1, y1)
        local wx2, wy2 = C_WorldMap.GetWorldPosition(z2, x2, y2)
        if wx1 and wy1 and wx2 and wy2 then
            local xDelta = wx2 - wx1
            local yDelta = wy2 - wy1
            local dist = math.sqrt(xDelta*xDelta + yDelta*yDelta)
            if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
            return dist, xDelta, yDelta
        end
    end
    
    local Map = self:GetModule("Map", true)
    if not (Map and Map.WorldMapSize) then 
        if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
        return nil 
    end
    
    local function getContPosition(c, z, x, y)
        local zData = Map.WorldMapSize[c] and Map.WorldMapSize[c][z]
        if not zData then return nil, nil end
        return x * zData.width + zData.xOffset, y * zData.height + zData.yOffset
    end
    
    local cx1, cy1 = getContPosition(c1, z1, x1, y1)
    local cx2, cy2 = getContPosition(c2, z2, x2, y2)
    if not cx1 or not cx2 then 
        if z1 == z2 then            
            local dx = x2 - x1
            local dy = y2 - y1
            local dist = math.sqrt(dx*dx + dy*dy) * 2000
            if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
            return dist, dx, dy
        end
        if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
        return nil 
    end
    
    local xDelta = cx2 - cx1
    local yDelta = cy2 - cy1
    local dist = math.sqrt(xDelta*xDelta + yDelta*yDelta)
    
    if pTime then self:ProfileStop("LootCollector:ComputeDistance", pTime) end
    return dist, xDelta, yDelta
end

function LootCollector:GetActiveRealmKey()
    if self.realmNameCached and self.realmNameCached ~= "Unknown Realm" then return self.realmNameCached end
    local realmName = nil
    if GetRealmName then
        realmName = GetRealmName()
    end
    if type(realmName) ~= "string" or realmName == "" or realmName == "Unknown Realm" then
        realmName = "Unknown Realm"
    else
        self.realmNameCached = realmName
    end
    return realmName
end

function LootCollector:ActivateRealmBucket()
    if not (self.db and self.db.global) then return end

    local g = self.db.global
    local realmKey = self:GetActiveRealmKey()

    g.realms = g.realms or {}
    g.realms[realmKey] = g.realms[realmKey] or {}
    local bucket = g.realms[realmKey]

    bucket.discoveries = bucket.discoveries or {}
    bucket.blackmarketVendors = bucket.blackmarketVendors or {}

    if g.discoveries and type(g.discoveries) == "table" then
        if g.discoveries ~= bucket.discoveries then
            local count = 0
            for k, v in pairs(g.discoveries) do
                if not bucket.discoveries[k] then
                    bucket.discoveries[k] = v
                    count = count + 1
                end
            end
            if count > 0 then
                print(string.format("|cff00ff00LootCollector:|r Migrated %d legacy global discoveries to realm bucket: %s", count, realmKey))
            end
        end
        g.discoveries = nil
    end

    if g.blackmarketVendors and type(g.blackmarketVendors) == "table" then
        if g.blackmarketVendors ~= bucket.blackmarketVendors then
             local count = 0
            for k, v in pairs(g.blackmarketVendors) do
                if not bucket.blackmarketVendors[k] then
                    bucket.blackmarketVendors[k] = v
                    count = count + 1
                end
            end
            if count > 0 then
                print(string.format("|cff00ff00LootCollector:|r Migrated %d legacy global vendors to realm bucket: %s", count, realmKey))
            end
        end
        g.blackmarketVendors = nil
    end

    self.activeRealmKey = realmKey

    local Constants = self:GetModule("Constants", true)
    if Constants then
        Constants:DetermineRealmCapabilities()
        Constants:UpdateAllowedTypes()
    end
end

function LootCollector:GetDiscoveriesDB()
    if not self.db or not self.db.global then return nil end
    local currentRealmKey = self:GetActiveRealmKey()
    if currentRealmKey ~= "Unknown Realm" and self.activeRealmKey ~= currentRealmKey then
        self:ActivateRealmBucket()
    end
    if not self.activeRealmKey then self:ActivateRealmBucket() end
    if self.db.global.realms and self.db.global.realms[self.activeRealmKey] then
        return self.db.global.realms[self.activeRealmKey].discoveries
    end
    return nil
end

function LootCollector:GetVendorsDB()
    if not self.db or not self.db.global then return nil end
    local currentRealmKey = self:GetActiveRealmKey()
    if currentRealmKey ~= "Unknown Realm" and self.activeRealmKey ~= currentRealmKey then
        self:ActivateRealmBucket()
    end
    if not self.activeRealmKey then self:ActivateRealmBucket() end
    if self.db.global.realms and self.db.global.realms[self.activeRealmKey] then
        return self.db.global.realms[self.activeRealmKey].blackmarketVendors
    end
    return nil
end

function LootCollector:ScheduleAfter(seconds, func)
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        return C_Timer.After(seconds, func)
    end
    local f = CreateFrame("Frame")
    local cancelled = false
    local target = GetTime() + (tonumber(seconds) or 0)
    f:SetScript("OnUpdate", function(self)
        if cancelled then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        if GetTime() >= target then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            func()
        end
    end)
    f:Show()
    return {
        Cancel = function() cancelled = true end,
        IsCancelled = function() return cancelled end,
    }
end

function LootCollector:BuildAreaIDToZoneIndex()
  if self.AIDToIndex then return end
  self._debug("Map", "Building AreaID-to-ZoneIndex translation table...")
  self.AIDToIndex = {}
local Map = self:GetModule("Map", true)
  if not Map then return end
  for c, continentData in pairs(Map.WorldMapSize) do
    if type(c) == "number" and c > 0 then
      self.AIDToIndex[c] = {}
      local zonesOnContinent = { GetMapZones(c) } 
      local nameToIndex = {}
      for i, name in ipairs(zonesOnContinent) do
        nameToIndex[name] = i
      end
      
      for areaID, zoneInfo in pairs(continentData) do
        local zoneName = zoneInfo.name
        local zoneIndex = nameToIndex[zoneName]
        if zoneIndex then
          self.AIDToIndex[c][areaID] = zoneIndex
          self._debug("Map", string.format("  -> Mapped [c=%d, areaID=%d, name=%s] to zoneIndex %d", c, areaID, zoneName, zoneIndex))
        end
      end
    end
  end
end

function LootCollector:AreaIDToZoneIndex(continent, areaID)
  self._debug("Map:AreaIDToZoneIndex - processing", string.format("[c=%d, areaID=%d]", tonumber(continent), tonumber(areaID)))
  if not continent or not areaID then return areaID end
  if not self.AIDToIndex then self:BuildAreaIDToZoneIndex() end
  
  continent = tonumber(continent)
  areaID = tonumber(areaID)
  
  local byCont = self.AIDToIndex and self.AIDToIndex[continent]
  local zoneIndex = byCont and byCont[areaID]
  
  if zoneIndex then
    self._debug("Map", string.format("Translated [c=%d, areaID=%d] -> zoneIndex %d", continent, areaID, zoneIndex))
    return zoneIndex
  end

  self._debug("Map", string.format("Translation FAILED for [c=%d, areaID=%d]. Falling back to areaID.", continent, areaID))
  return areaID
end

function LootCollector.ResolveZoneDisplay(continent, zoneID, iz)
    local ZoneList = LootCollector:GetModule("ZoneList", true)
    local mapID = tonumber(zoneID) or 0 
    if ZoneList and ZoneList.MapDataByID and ZoneList.MapDataByID[mapID] then
        return ZoneList.MapDataByID[mapID].name
    end
    return (GetRealZoneText and GetRealZoneText()) or "Unknown Zone"
end

local STATUS_FADING = "FADING"
local STATUS_STALE = "STALE"
local STATUS_UNCONFIRMED = "UNCONFIRMED"

function LootCollector:GetFilters()
    local c = self.db and self.db.char
    local p = self.db and self.db.profile
    local f = (c and c.mapFilters) or {}
    local ui = (p and p.mapFilters) or {}
    
    
    local combined = {}
    
    
    combined.hideAll = f.hideAll or false
    combined.hideFaded = f.hideFaded or false
    combined.hideStale = f.hideStale or false
    combined.hideLooted = f.hideLooted or false
    combined.hideUnconfirmed = f.hideUnconfirmed or false
    combined.hideUncached = f.hideUncached or false
    combined.hideLearnedTransmog = f.hideLearnedTransmog or false
    combined.hideCollectedME = f.hideCollectedME or false
    combined.hideBags = f.hideBags or false
    combined.minRarity = f.minRarity or 0
    combined.allowedEquipLoc = f.allowedEquipLoc or {}
    combined.usableByClasses = f.usableByClasses or {}
    combined.showMysticScrolls = f.showMysticScrolls ~= false
    combined.showWorldforged = f.showWorldforged ~= false
    combined.showVendors = f.showVendors ~= false
    combined.applyViewerFiltersOnMap = f.applyViewerFiltersOnMap or false
    combined.autoTrackNearest = f.autoTrackNearest or false

    
    combined.showMinimap = ui.showMinimap ~= false
    combined.maxMinimapDistance = ui.maxMinimapDistance or 800
    combined.pinSize = ui.pinSize or 16
    combined.minimapPinSize = ui.minimapPinSize or 10
    combined.disableFadeEffect = ui.disableFadeEffect or false
    combined.showZoneSummaries = ui.showZoneSummaries or false
    combined.disableProximityList = ui.disableProximityList or false
	combined.enableChatLinkIntegration = ui.enableChatLinkIntegration ~= false
    
    return combined
end

function LootCollector:GetDiscoveryStatus(d)
    local s = (d and d.s) or STATUS_UNCONFIRMED
    if s == STATUS_FADING or s == STATUS_STALE or s == "CONFIRMED" or s == STATUS_UNCONFIRMED then
        return s
    end
    return STATUS_UNCONFIRMED
end

function LootCollector:IsLootedByChar(guid)
    if not guid or not (self.db and self.db.char and self.db.char.looted) then return false end
    return self.db.char.looted[guid] and true or false
end

local function _earlierTs(a, b)
    a, b = tonumber(a), tonumber(b)
    if a and b then return (a < b) and a or b end
    return a or b
end

local function _countLootedKeys(t)
    local n = 0
    if type(t) ~= "table" then return 0 end
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function LootCollector:GetLootedCharKey()
    if self.db and self.db.keys and type(self.db.keys.char) == "string" and self.db.keys.char ~= "" then
        return self.db.keys.char
    end
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if type(name) == "string" and name ~= "" and type(realm) == "string" and realm ~= "" then
        return name .. " - " .. realm
    end
    return nil
end

function LootCollector:GetLootedArchive(charKey)
    if not (self.db and self.db.global) then return nil end
    charKey = charKey or self:GetLootedCharKey()
    if not charKey then return nil end
    self.db.global.lootedArchive = self.db.global.lootedArchive or {}
    local arch = self.db.global.lootedArchive[charKey]
    if type(arch) ~= "table" then
        arch = {}
        self.db.global.lootedArchive[charKey] = arch
    end
    return arch
end

function LootCollector:ArchiveLootedGuid(guid, timestamp)
    if not guid then return end
    local arch = self:GetLootedArchive()
    if not arch then return end
    local ts = tonumber(timestamp) or time()
    local existing = arch[guid]
    arch[guid] = existing and _earlierTs(existing, ts) or ts
end

function LootCollector:GetLootedLayerCounts()
    local live = _countLootedKeys(self.db and self.db.char and self.db.char.looted)
    local backup = _countLootedKeys(self.db and self.db.char and self.db.char.lootedBackup)
    local archive = _countLootedKeys(self:GetLootedArchive())
    return live, backup, archive
end

function LootCollector:ClearLiveLootedHistory()
    if not (self.db and self.db.char) then return false end
    self.db.char.looted = {}
    print("|cff00ff00LootCollector:|r Looted history cleared for this character (backup and archive kept).")

    local Map = self:GetModule("Map", true)
    if Map then
        Map.cacheIsDirty = true
        if Map.Update and WorldMapFrame and WorldMapFrame:IsShown() then
            Map:Update()
        end
        if Map.UpdateMinimap then Map:UpdateMinimap() end
    end

    local Viewer = self:GetModule("Viewer", true)
    if Viewer then
        if Viewer.InvalidateFilterCache then Viewer:InvalidateFilterCache() end
        if Viewer.window and Viewer.window:IsShown() and Viewer.RefreshData then
            Viewer:RefreshData()
        end
    end
    return true
end

local _LC_POPUPS_BLOCKING_PRESTIGE = {
    "LOOTCOLLECTOR_WELCOME",
    "LOOTCOLLECTOR_PUBLIC_CHANNEL_PROMPT",
    "LOOTCOLLECTOR_OPTIONAL_DB_UPDATE",
    "LOOTCOLLECTOR_MIGRATION_RELOAD",
    "LOOTCOLLECTOR_PRESTIGE_CLEAR_LOOTED",
}

local function _IsLootCollectorPopupVisible()
    if not StaticPopup_Visible then return false end
    for i = 1, #_LC_POPUPS_BLOCKING_PRESTIGE do
        if StaticPopup_Visible(_LC_POPUPS_BLOCKING_PRESTIGE[i]) then
            return true
        end
    end
    return false
end

function LootCollector:RememberPlayerLevel(level)
    if not (self.db and self.db.char) then return end
    level = tonumber(level)
    if not level or level < 1 then return end
    self.db.char.lastSeenLevel = level
end

function LootCollector:CheckPrestigeLevelDrop()
    if self.LEGACY_MODE_ACTIVE then return end
    if not (self.db and self.db.char) then return end

    local current = tonumber(UnitLevel and UnitLevel("player"))
    if not current or current < 1 then return end

    local stored = tonumber(self.db.char.lastSeenLevel)
    if not stored then
        self.db.char.lastSeenLevel = current
        return
    end

    local live = _countLootedKeys(self.db.char.looted)
    if current <= 5 and stored > current and live > 0 then
        if StaticPopup_Visible and StaticPopup_Visible("LOOTCOLLECTOR_PRESTIGE_CLEAR_LOOTED") then
            return
        end
        StaticPopup_Show(
            "LOOTCOLLECTOR_PRESTIGE_CLEAR_LOOTED",
            tostring(stored),
            tostring(current),
            { afterLevel = current }
        )
        return
    end

    self.db.char.lastSeenLevel = current
end

function LootCollector:SchedulePrestigeLevelCheck()
    if self._prestigeCheckScheduled then return end
    self._prestigeCheckScheduled = true
    self:ScheduleAfter(3.0, function()
        if _IsLootCollectorPopupVisible() then
            LootCollector:ScheduleAfter(3.0, function()
                LootCollector:CheckPrestigeLevelDrop()
            end)
            return
        end
        LootCollector:CheckPrestigeLevelDrop()
    end)
end

function LootCollector:UpdateLootedHighWater()
    local charKey = self:GetLootedCharKey()
    if not charKey or not (self.db and self.db.global) then return end
    local live, backup, archive = self:GetLootedLayerCounts()
    local current = math.max(live, backup, archive)
    self.db.global.lootedHighWater = self.db.global.lootedHighWater or {}
    local hw = self.db.global.lootedHighWater[charKey]
    local prev = (type(hw) == "table" and tonumber(hw.n)) or 0
    if current > prev then
        self.db.global.lootedHighWater[charKey] = { n = current, t = time() }
    end
end

function LootCollector:SeedLootedArchiveFromLayers()
    if not (self.db and self.db.char) then return end
    local arch = self:GetLootedArchive()
    if not arch then return end
    self.db.char.looted = self.db.char.looted or {}
    self.db.char.lootedBackup = self.db.char.lootedBackup or {}
    for guid, ts in pairs(self.db.char.looted) do
        local existing = arch[guid]
        arch[guid] = existing and _earlierTs(existing, ts) or ts
    end
    for guid, ts in pairs(self.db.char.lootedBackup) do
        local existing = arch[guid]
        arch[guid] = existing and _earlierTs(existing, ts) or ts
    end
end

function LootCollector:MarkLooted(guid, timestamp)
    if not guid or not (self.db and self.db.char) then return end
    local ts = tonumber(timestamp) or time()
    self.db.char.looted = self.db.char.looted or {}
    self.db.char.lootedBackup = self.db.char.lootedBackup or {}
    self.db.char.looted[guid] = ts
    local bak = self.db.char.lootedBackup[guid]
    self.db.char.lootedBackup[guid] = bak and _earlierTs(bak, ts) or ts
    self:ArchiveLootedGuid(guid, ts)
    self:UpdateLootedHighWater()
end

-- WF is one spawn per item. Looting it marks every realm pin for that base ID.
-- Class/weapon usability is not a gate.
function LootCollector:MarkWorldforgedItemLooted(itemID, timestamp)
    itemID = tonumber(itemID)
    if not itemID or itemID == 0 then return 0 end
    local db = self.GetDiscoveriesDB and self:GetDiscoveriesDB()
    if not db then return 0 end
    local Constants = self:GetModule("Constants", true)
    local WF = Constants and Constants.DISCOVERY_TYPE and Constants.DISCOVERY_TYPE.WORLDFORGED
    local base = (self.GetBaseItemID and self:GetBaseItemID(itemID)) or itemID
    local ids = { [itemID] = true, [base] = true }
    local upgrades = self.WorldforgedUpgrades and self.WorldforgedUpgrades[base]
    if upgrades then
        for _, uid in pairs(upgrades) do
            uid = tonumber(uid)
            if uid then ids[uid] = true end
        end
    end
    local n = 0
    for guid, rec in pairs(db) do
        if type(rec) == "table" then
            local ri = tonumber(rec.i)
            if ri and ids[ri] and (not WF or rec.dt == nil or rec.dt == WF) then
                self:MarkLooted(rec.g or guid, timestamp)
                n = n + 1
            end
        end
    end
    if n > 0 then
        local Map = self:GetModule("Map", true)
        if Map then Map.cacheIsDirty = true end
        self.DataHasChanged = true
    end
    return n
end

function LootCollector:UnmarkLooted(guid)
    if not guid or not (self.db and self.db.char and self.db.char.looted) then return end
    self.db.char.looted[guid] = nil
end

function LootCollector:RemapLootedGuid(oldGuid, newGuid)
    if not oldGuid or not newGuid or oldGuid == newGuid then return end
    if not (self.db and self.db.char) then return end
    self.db.char.looted = self.db.char.looted or {}
    self.db.char.lootedBackup = self.db.char.lootedBackup or {}

    local liveTs = self.db.char.looted[oldGuid]
    if liveTs ~= nil then
        local existing = self.db.char.looted[newGuid]
        self.db.char.looted[newGuid] = existing and _earlierTs(existing, liveTs) or liveTs
        self.db.char.looted[oldGuid] = nil
    end

    local bakTs = self.db.char.lootedBackup[oldGuid]
    if bakTs ~= nil then
        local existing = self.db.char.lootedBackup[newGuid]
        self.db.char.lootedBackup[newGuid] = existing and _earlierTs(existing, bakTs) or bakTs
        self.db.char.lootedBackup[oldGuid] = nil
    end

    local arch = self:GetLootedArchive()
    if arch then
        local archTs = arch[oldGuid]
        if archTs ~= nil then
            local existing = arch[newGuid]
            arch[newGuid] = existing and _earlierTs(existing, archTs) or archTs
            arch[oldGuid] = nil
        end
    end
end

local function _parseLootedGuidFields(guid)
    if type(guid) ~= "string" then return nil end
    -- V8: c-z-iz-i-x-y
    local c, z, iz, i, x, y = guid:match("^(%d+)%-(%d+)%-(%d+)%-(%d+)%-([%d%.]+)%-([%d%.]+)$")
    if c then
        return tonumber(c), tonumber(z), tonumber(iz), tonumber(i), tonumber(x), tonumber(y)
    end
    -- V7 legacy: c-z-i-x-y
    c, z, i, x, y = guid:match("^(%d+)%-(%d+)%-(%d+)%-([%d%.]+)%-([%d%.]+)$")
    if c then
        return tonumber(c), tonumber(z), 0, tonumber(i), tonumber(x), tonumber(y)
    end
    return nil
end

-- Merge lootedBackup (+ account archive) into live looted; rematch orphan GUIDs.
-- Returns exactRestored, rematched, stillOrphan.
function LootCollector:HealLootedFromBackup()
    if not (self.db and self.db.char) then return 0, 0, 0 end
    self.db.char.looted = self.db.char.looted or {}
    self.db.char.lootedBackup = self.db.char.lootedBackup or {}

    for guid, ts in pairs(self.db.char.looted) do
        if self.db.char.lootedBackup[guid] == nil then
            self.db.char.lootedBackup[guid] = ts
        end
    end
    self:SeedLootedArchiveFromLayers()

    local discoveries = self.GetDiscoveriesDB and self:GetDiscoveriesDB() or nil
    if not discoveries then return 0, 0, 0 end

    local byKey = {}
    for _, d in pairs(discoveries) do
        if d and d.i and d.z ~= nil then
            local c = tonumber(d.c) or 0
            local z = tonumber(d.z) or 0
            local iz = tonumber(d.iz) or 0
            local i = tonumber(d.i) or 0
            local key = c .. "-" .. z .. "-" .. iz .. "-" .. i
            byKey[key] = byKey[key] or {}
            table.insert(byKey[key], d)
        end
    end

    local exactRestored, rematched, stillOrphan = 0, 0, 0
    local healSnapshot = {}
    for guid, ts in pairs(self.db.char.lootedBackup) do
        healSnapshot[guid] = ts
    end
    local archive = self:GetLootedArchive()
    if archive then
        for guid, ts in pairs(archive) do
            local existing = healSnapshot[guid]
            healSnapshot[guid] = existing and _earlierTs(existing, ts) or ts
        end
    end

    for guid, ts in pairs(healSnapshot) do
        ts = tonumber(ts) or time()
        if discoveries[guid] then
            if not self.db.char.looted[guid] then
                self.db.char.looted[guid] = ts
                exactRestored = exactRestored + 1
            end
            if self.db.char.lootedBackup[guid] == nil then
                self.db.char.lootedBackup[guid] = ts
            end
            self:ArchiveLootedGuid(guid, ts)
        else
            local c, z, iz, i, x, y = _parseLootedGuidFields(guid)
            local matched = nil
            if c and i then
                local key = c .. "-" .. z .. "-" .. iz .. "-" .. i
                local candidates = byKey[key]
                if candidates and #candidates == 1 then
                    matched = candidates[1]
                elseif candidates and #candidates > 1 then
                    local best, bestDist = nil, nil
                    for _, d in ipairs(candidates) do
                        local dx = (d.xy and d.xy.x) or 0
                        local dy = (d.xy and d.xy.y) or 0
                        local dist
                        if self.ComputeDistance then
                            dist = self:ComputeDistance(c, z, x or 0, y or 0, d.c, d.z, dx, dy)
                        else
                            dist = math.abs((x or 0) - dx) + math.abs((y or 0) - dy)
                        end
                        if dist and (not bestDist or dist < bestDist) then
                            best, bestDist = d, dist
                        end
                    end
                    if best and (not bestDist or bestDist <= 80) then
                        matched = best
                    end
                end
            end

            if matched and matched.g then
                local newGuid = matched.g
                if not self.db.char.looted[newGuid] then
                    self.db.char.looted[newGuid] = ts
                    rematched = rematched + 1
                end
                if newGuid ~= guid then
                    self:RemapLootedGuid(guid, newGuid)
                end
                if self.db.char.lootedBackup[newGuid] == nil then
                    self.db.char.lootedBackup[newGuid] = ts
                end
                self:ArchiveLootedGuid(newGuid, ts)
            else
                stillOrphan = stillOrphan + 1
            end
        end
    end

    self:UpdateLootedHighWater()
    return exactRestored, rematched, stillOrphan
end

-- Login safety: seed layers, detect sudden drops vs high-water, heal, update high-water.
-- Returns exactRestored, rematched, stillOrphan, dropDetected.
function LootCollector:EnsureLootedSafetyNets(hideMsgs)
    if not (self.db and self.db.char) then return 0, 0, 0, false end
    self:SeedLootedBackupFromLive()
    self:SeedLootedArchiveFromLayers()

    local live, backup, archive = self:GetLootedLayerCounts()
    local charKey = self:GetLootedCharKey()
    local high = 0
    if charKey and self.db.global and self.db.global.lootedHighWater then
        local hw = self.db.global.lootedHighWater[charKey]
        high = (type(hw) == "table" and tonumber(hw.n)) or 0
    end

    local dropDetected = high >= 10 and live < (high * 0.5) and backup < (high * 0.5)
    if dropDetected and not hideMsgs then
        print(string.format(
            "|cffff7f00LootCollector:|r Looted history drop detected (live=%d backup=%d archive=%d, previous high=%d). Attempting restore...",
            live, backup, archive, high
        ))
    end

    local exact, rematched, orphan = self:HealLootedFromBackup()
    local restored = (exact or 0) + (rematched or 0)
    live, backup, archive = self:GetLootedLayerCounts()

    if dropDetected and not hideMsgs then
        if restored > 0 then
            print(string.format(
                "|cff00ff00LootCollector:|r Restored %d looted pin(s) after drop detection (%d exact, %d rematched). Now live=%d backup=%d archive=%d.",
                restored, exact or 0, rematched or 0, live, backup, archive
            ))
        else
            print(string.format(
                "|cffff7f00LootCollector:|r Could not restore looted pins (live=%d backup=%d archive=%d). Re-mark as you loot.",
                live, backup, archive
            ))
        end
    elseif restored > 0 and not hideMsgs then
        print(string.format(
            "|cff00ff00LootCollector:|r Restored %d looted pin(s) from backup/archive (%d exact, %d rematched).",
            restored, exact or 0, rematched or 0
        ))
    end

    self:UpdateLootedHighWater()
    return exact, rematched, orphan, dropDetected
end

function LootCollector:SeedLootedBackupFromLive()
    if not (self.db and self.db.char) then return end
    self.db.char.looted = self.db.char.looted or {}
    self.db.char.lootedBackup = self.db.char.lootedBackup or {}
    for guid, ts in pairs(self.db.char.looted) do
        if self.db.char.lootedBackup[guid] == nil then
            self.db.char.lootedBackup[guid] = ts
        end
    end
end

-- Favorites storage: shared (profile) by default; optional per-character (char).
function LootCollector:GetFavoritesDB()
    if not self.db then return {} end
    if self.db.profile and self.db.profile.perCharacterFavorites then
        self.db.char = self.db.char or {}
        self.db.char.favorites = self.db.char.favorites or {}
        return self.db.char.favorites
    end
    self.db.profile = self.db.profile or {}
    self.db.profile.favorites = self.db.profile.favorites or {}
    return self.db.profile.favorites
end

-- Enable/disable per-character Favorites. On first enable for this character,
-- copy profile.favorites into char.favorites when the char list is empty.
-- Disabling returns to the shared profile list without wiping either table.
function LootCollector:SetPerCharacterFavorites(enabled)
    if not (self.db and self.db.profile) then return end
    enabled = enabled and true or false
    local p = self.db.profile
    local was = p.perCharacterFavorites and true or false
    if was == enabled then return end

    p.perCharacterFavorites = enabled
    if enabled then
        self.db.char = self.db.char or {}
        self.db.char.favorites = self.db.char.favorites or {}
        if not next(self.db.char.favorites) and p.favorites then
            for itemID, val in pairs(p.favorites) do
                self.db.char.favorites[itemID] = val
            end
        end
    end

    local Viewer = self:GetModule("Viewer", true)
    if Viewer then
        if Viewer.InvalidateFilterCache then Viewer:InvalidateFilterCache() end
        if Viewer.window and Viewer.window:IsShown() and Viewer.RefreshData then
            Viewer:RefreshData()
        end
        if Viewer.ScheduleMapViewerFilterNotify then
            Viewer:ScheduleMapViewerFilterNotify()
        end
    end
end

local appearanceCache = {}
local appearanceCacheTime = {}
local APPEARANCE_CACHE_DURATION = 300

function LootCollector:IsMysticEnchantCollected(itemID)
    if not itemID or itemID == 0 then return false end

    
    local nowTime = GetTime()
    if meCollectedCacheTime[itemID] and (nowTime - meCollectedCacheTime[itemID]) < ME_COLLECTED_CACHE_DURATION then
        return meCollectedCache[itemID]
    end

    local isCollected = false
    if C_MysticEnchant and C_MysticEnchant.IsCollected then
        local ok, result = pcall(C_MysticEnchant.IsCollected, itemID)
        if ok and result then
            isCollected = true
        end
    end

    if not isCollected then
        local Scanner = self:GetModule("Scanner", true)
        if Scanner then
            local itemData = Scanner:GetItemData(itemID)
            if itemData and itemData.isCollected then
                isCollected = true
            end
        end
    end

    meCollectedCache[itemID] = isCollected
    meCollectedCacheTime[itemID] = nowTime

    return isCollected
end

function LootCollector:IsAppearanceCollected(itemID)
    if not itemID or itemID == 0 then return false end
    if not C_Appearance or not C_AppearanceCollection then return false end
    
    local now = GetTime()
    if appearanceCacheTime[itemID] and (now - appearanceCacheTime[itemID]) < APPEARANCE_CACHE_DURATION then
        return appearanceCache[itemID]
    end
    
    local isCollected = false
    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
    if appearanceID then
        isCollected = C_AppearanceCollection.IsAppearanceCollected(appearanceID) or false
    end
    
    appearanceCache[itemID] = isCollected
    appearanceCacheTime[itemID] = now
    
    return isCollected
end

-- Precomputed usable-by IST sets (rebuilt when usableByClasses membership changes).
local _filterIstCache = {
    key = nil,
    armor = {},
    weapons = {},
}

local function _usableByClassesKey(usableByClasses)
    if not usableByClasses or not next(usableByClasses) then return "" end
    local parts = {}
    for classToken, enabled in pairs(usableByClasses) do
        if enabled then
            parts[#parts + 1] = classToken
        end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

local function _ensureAllowedIstSets(usableByClasses, Constants)
    local key = _usableByClassesKey(usableByClasses)
    if _filterIstCache.key == key then
        return _filterIstCache.armor, _filterIstCache.weapons
    end
    wipe(_filterIstCache.armor)
    wipe(_filterIstCache.weapons)
    _filterIstCache.key = key
    if key == "" or not Constants or not Constants.CLASS_PROFICIENCIES then
        return _filterIstCache.armor, _filterIstCache.weapons
    end
    for classToken, enabled in pairs(usableByClasses) do
        if enabled then
            local proficiencies = Constants.CLASS_PROFICIENCIES[classToken]
            if proficiencies then
                if proficiencies.armor then
                    for _, ist in ipairs(proficiencies.armor) do
                        _filterIstCache.armor[ist] = true
                    end
                end
                if proficiencies.weapons then
                    for _, ist in ipairs(proficiencies.weapons) do
                        _filterIstCache.weapons[ist] = true
                    end
                end
            end
        end
    end
    return _filterIstCache.armor, _filterIstCache.weapons
end

local function _resolveEquipLoc(d, Constants)
    -- Prefer persisted equipLoc written from a real GetItemInfo result.
    if d.el and d.el ~= "" then
        return d.el
    end
    local _, _, _, _, _, _, _, _, cachedEquipLoc = GetItemInfo(d.il or d.i or 0)
    if cachedEquipLoc and cachedEquipLoc ~= "" then
        d.el = cachedEquipLoc
        return cachedEquipLoc
    end
    -- IST fallback matches prior filter behavior but is not a true equip slot —
    -- do not persist it on the discovery record.
    if d.ist and d.ist > 0 and Constants and Constants.IST_TO_EQUIPLOC and Constants.IST_TO_EQUIPLOC[d.ist] then
        return Constants.IST_TO_EQUIPLOC[d.ist]
    end
    return nil
end

function LootCollector:DiscoveryPassesFilters(d)
    local Constants = self:GetModule("Constants", true)
    local f = self:GetFilters()
    if not d or f.hideAll then return false end

    -- When Filter Map is ON, Viewer owns overlapping dimensions (slots, usable-by,
    -- rarity, looted, collected ME, fade/stale). Skip those map knobs so they cannot fight Viewer.
    local skipOverlap = f.applyViewerFiltersOnMap

    local dt = d and (d.dt or (Constants and Constants.DISCOVERY_TYPE.UNKNOWN) or 0)
    if (Constants and dt == Constants.DISCOVERY_TYPE.BLACKMARKET) or (d and d.vendorType) then
        return f.showVendors ~= false
    end

    local s = self:GetDiscoveryStatus(d)
    if (s == STATUS_UNCONFIRMED and f.hideUnconfirmed) or
       (not skipOverlap and s == STATUS_FADING and f.hideFaded) or
       (not skipOverlap and s == STATUS_STALE and f.hideStale) then
        return false
    end
    if not skipOverlap and f.hideLooted and d.g and self:IsLootedByChar(d.g) then
        return false
    end

    if f.hideLearnedTransmog and d.i and d.i > 0 and self:IsAppearanceCollected(d.i) then
        return false
    end

    if not skipOverlap and f.hideCollectedME and Constants and d.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL and d.i and d.i > 0 and self:IsMysticEnchantCollected(d.i) then
        return false
    end
	
	if f.hideBags and d.it == 2 then
        return false
    end

    if not skipOverlap then
        local quality = d.q or 0
        if quality < (f.minRarity or 0) then return false end
    end

    if not Constants then return true end

    if dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL and not f.showMysticScrolls then return false end
    if dt == Constants.DISCOVERY_TYPE.WORLDFORGED  and not f.showWorldforged  then return false end

    if not skipOverlap and next(f.usableByClasses) then
        local canBeUsed = false
        local isMysticScroll = (d.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL)
        if isMysticScroll then
            local itemClassToken = (d.cl and d.cl ~= "cl") and Constants.CLASS_ABBREVIATIONS_REVERSE and Constants.CLASS_ABBREVIATIONS_REVERSE[d.cl]
            if itemClassToken and f.usableByClasses[itemClassToken] then
                canBeUsed = true
            end
        else 
            local itemType = d.it
            local itemSubType = d.ist
            local isProficiencyArmor = Constants.PROFICIENCY_ARMOR_ISTS and Constants.PROFICIENCY_ARMOR_ISTS[itemSubType]
            local isWeapon = (itemType == Constants.ITEM_TYPE_TO_ID["Weapon"])
            
            if isProficiencyArmor or isWeapon then
                if not Constants.CLASS_PROFICIENCIES then return true end
                local allowedArmor, allowedWeapons = _ensureAllowedIstSets(f.usableByClasses, Constants)
                if isProficiencyArmor then
                    canBeUsed = allowedArmor[itemSubType] == true
                else
                    canBeUsed = allowedWeapons[itemSubType] == true
                end
            else
                canBeUsed = true
            end
        end
        if not canBeUsed then return false end
    end

    if not skipOverlap and next(f.allowedEquipLoc) then
        local equipLoc = _resolveEquipLoc(d, Constants)
        
        if equipLoc and not f.allowedEquipLoc[equipLoc] then
            return false
        elseif not equipLoc then
            return false
        end
    end

    return true
end

StaticPopupDialogs["LOOTCOLLECTOR_MIGRATION_RELOAD"] = {
  text = "LootCollector has successfully upgraded your database.\n\nA UI reload is required to save these changes.\n\nThis is a one-time process.",
  button1 = "Reload Now",
  OnAccept = function()
    ReloadUI()
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 0, 
  exclusive = 1,
  showAlert = true,
}

function LootCollector:PreInitializeMigration()
    if not (_G.LootCollectorDB_Asc and type(_G.LootCollectorDB_Asc) == "table") then
        self.LEGACY_MODE_ACTIVE = false 
        return
    end

    local rawDB = _G.LootCollectorDB_Asc
    -- Canonical key is _schemaVersion. Promote legacy schemaVersion once, then drop it
    -- so AceDB init cannot leave only the bare key and force a re-migrate next login.
    if rawDB._schemaVersion == nil and rawDB.schemaVersion ~= nil then
        rawDB._schemaVersion = tonumber(rawDB.schemaVersion) or 0
    end
    rawDB.schemaVersion = nil
    local currentSchema = tonumber(rawDB._schemaVersion) or 0

    if currentSchema >= 8 then
        self.LEGACY_MODE_ACTIVE = false 
        return
    end
    
    self.MIGRATION_JUST_HAPPENED = true

    local cityZoneIDsToPurge = {[1]={[382]=true,[322]=true,[363]=true,[1204]=true},[2]={[342]=true,[302]=true,[383]=true},[3]={[482]=true},[4]={[505]=true}}
    local Constants = self:GetModule("Constants", true)
    local HASH_SAP = (Constants and Constants.HASH_SAP) or "LC@Asc.BB25"
    local HASH_SEED = (Constants and Constants.HASH_SEED) or 2025
    local cHASH_BLACKLIST = (Constants and Constants.cHASH_BLACKLIST) or {}
    local AcceptedLootSrcMS = Constants and Constants.AcceptedLootSrcMS

    local function _isFinderOnBlacklist(name)
        if not name or name == "" or not _G.XXH_Lua_Lib then return false end
        local normalizedName = (string.match(name, "([^%-]+)") or name):gsub("^%s+", ""):gsub("%s+$", "")
        if not normalizedName or normalizedName == "" then return false end
        local combined_str = normalizedName .. HASH_SAP
        local hash_val = _G.XXH_Lua_Lib.XXH32(combined_str, HASH_SEED)
        local hex_hash = string.format("%08x", hash_val)
        return cHASH_BLACKLIST[hex_hash] == true
    end

    local function PurgeByFinderBlacklist(discoveries)
        if not discoveries then return 0 end
        local guidsToRemove = {}
        for guid, d in pairs(discoveries) do
            if d and d.fp and _isFinderOnBlacklist(d.fp) then table.insert(guidsToRemove, guid) end
        end
        for _, guid in ipairs(guidsToRemove) do discoveries[guid] = nil end
        return #guidsToRemove
    end
    
    local function PurgeByCityZones(discoveries)
        if not discoveries then return 0 end
        local guidsToRemove = {}
        for guid, d in pairs(discoveries) do
            if d and d.c and d.z and cityZoneIDsToPurge[tonumber(d.c)] and cityZoneIDsToPurge[tonumber(d.c)][tonumber(d.z)] then
                table.insert(guidsToRemove, guid)
            end
        end
        for _, guid in ipairs(guidsToRemove) do discoveries[guid] = nil end
        return #guidsToRemove
    end

    local function PurgeZeroCoordDiscoveries(discoveries)
        if not discoveries then return 0 end
        local guidsToRemove = {}
        for guid, d in pairs(discoveries) do
            if d and d.xy and tonumber(d.xy.x) == 0 and tonumber(d.xy.y) == 0 then
                table.insert(guidsToRemove, guid)
            end
        end
        for _, guid in ipairs(guidsToRemove) do discoveries[guid] = nil end
        return #guidsToRemove
    end

    local function GenerateLegacyGUID(c, mapID, i, x, y)
        local x2 = math.floor((tonumber(x) or 0) * 100 + 0.5) / 100
        local y2 = math.floor((tonumber(y) or 0) * 100 + 0.5) / 100
        return tostring(c or 0) .. "-" .. tostring(mapID or 0) .. "-" .. tostring(i or 0) .. "-" .. string.format("%.2f", x2) .. "-" .. string.format("%.2f", y2)
    end

    
    
    
    if currentSchema < 7 then
        local LegacyZoneData = {[1]={[1]="Ammen Vale",[2]="Ashenvale",[3]="Azshara",[4]="Azuremyst Isle",[5]="Ban'ethil Barrow Den",[6]="Bloodmyst Isle",[7]="Burning Blade Coven",[8]="Caverns of Time",[9]="Darkshore",[10]="Darnassus",[11]="Desolace",[12]="Durotar",[13]="Dustwallow Marsh",[14]="Dustwind Cave",[15]="Fel Rock",[16]="Felwood",[17]="Feralas",[18]="Maraudon",[19]="Moonglade",[20]="Moonlit Ossuary",[21]="Mulgore",[22]="Orgrimmar",[23]="Palemane Rock",[24]="Camp Narache",[25]="Shadowglen",[26]="Shadowthread Cave",[27]="Silithus",[28]="Sinister Lair",[29]="Skull Rock",[30]="Stillpine Hold",[31]="Stonetalon Mountains",[32]="Tanaris",[33]="Teldrassil",[34]="The Barrens",[35]="The Exodar",[36]="The Gaping Chasm",[37]="The Noxious Lair",[38]="The Slithering Scar",[39]="The Venture Co. Mine",[40]="Thousand Needles",[41]="Thunder Bluff",[42]="Tides' Hollow",[43]="Twilight's Run",[44]="Un'Goro Crater",[45]="Valley of Trials",[46]="Wailing Caverns",[47]="Winterspring"},[2]={[1]="Alterac Mountains",[2]="Amani Catacombs",[3]="Arathi Highlands",[4]="Badlands",[5]="Blackrock Mountain",[6]="Blasted Lands",[7]="Burning Steppes",[8]="Coldridge Pass",[9]="Coldridge Valley",[10]="Deadwind Pass",[11]="Deathknell",[12]="Dun Morogh",[13]="Duskwood",[14]="Eastern Plaguelands",[15]="Echo Ridge Mine",[16]="Elwynn Forest",[17]="Eversong Woods",[18]="Fargodeep Mine",[19]="Ghostlands",[20]="Gol'Bolar Quarry",[21]="Gold Coast Quarry",[22]="Hillsbrad Foothills",[23]="Ironforge",[24]="Isle of Quel'Danas",[25]="Jangolode Mine",[26]="Jasperlode Mine",[27]="Loch Modan",[28]="Night Web's Hollow",[29]="Northshire Valley",[30]="Redridge Mountains",[31]="Scarlet Monastery",[32]="Searing Gorge",[33]="Secret Inquisitorial Dungeon",[34]="Shadewell Spring",[35]="Silvermoon City",[36]="Silverpine Forest",[37]="Stormwind City",[38]="Stranglethorn Vale",[39]="Sunstrider Isle",[40]="Swamp of Sorrows",[41]="The Deadmines",[42]="The Grizzled Den",[43]="The Hinterlands",[44]="Tirisfal Glades",[45]="Uldaman",[46]="Undercity",[47]="Western Plaguelands",[48]="Westfall",[49]="Wetlands"}}
        local LegacyInstanceData = {[1]="Ragefire Chasm",[2]="Wailing Caverns",[3]="The Deadmines",[4]="Shadowfang Keep",[5]="The Stockade",[6]="Blackfathom Deeps",[7]="Gnomeregan",[8]="Razorfen Kraul",[9]="Scarlet Monastery",[10]="Razorfen Downs",[11]="Uldaman",[12]="Zul'Farrak",[13]="Maraudon",[14]="The Temple of Atal'hakkar",[15]="Blackrock Depths",[16]="Dire Maul",[17]="Lower Blackrock Spire",[18]="Upper Blackrock Spire",[19]="Scholomance",[20]="Stratholme",[21]="Molten Core",[22]="Onyxia's Lair",[23]="Blackwing Lair",[24]="Zul'Gurub",[25]="Ruins of Ahn'Qiraj",[26]="Temple of Ahn'Qiraj"}
        local NewMapDataByID = {[5]={name="Durotar"},[10]={name="Mulgore"},[12]={name="The Barrens"},[16]={name="Alterac Mountains"},[17]={name="Arathi Highlands"},[18]={name="Badlands"},[20]={name="Blasted Lands"},[21]={name="Tirisfal Glades"},[22]={name="Silverpine Forest"},[23]={name="Western Plaguelands"},[24]={name="Eastern Plaguelands"},[25]={name="Hillsbrad Foothills"},[27]={name="The Hinterlands"},[28]={name="Dun Morogh"},[29]={name="Searing Gorge"},[30]={name="Burning Steppes"},[31]={name="Elwynn Forest"},[33]={name="Deadwind Pass"},[35]={name="Duskwood"},[36]={name="Loch Modan"},[37]={name="Redridge Mountains"},[38]={name="Stranglethorn Vale"},[39]={name="Swamp of Sorrows"},[40]={name="Westfall"},[41]={name="Wetlands"},[42]={name="Teldrassil"},[43]={name="Darkshore"},[44]={name="Ashenvale"},[62]={name="Thousand Needles"},[82]={name="Stonetalon Mountains"},[102]={name="Desolace"},[122]={name="Feralas"},[142]={name="Dustwallow Marsh"},[162]={name="Tanaris"},[182]={name="Azshara"},[183]={name="Felwood"},[202]={name="Un'Goro Crater"},[242]={name="Moonglade"},[262]={name="Silithus"},[282]={name="Winterspring"},[302]={name="Stormwind City"},[322]={name="Orgrimmar"},[342]={name="Ironforge"},[363]={name="Thunder Bluff"},[382]={name="Darnassus"},[383]={name="Undercity"},[463]={name="Eversong Woods"},[464]={name="Ghostlands"},[465]={name="Azuremyst Isle"},[472]={name="The Exodar"},[477]={name="Bloodmyst Isle"},[481]={name="Silvermoon City"},[681]={name="Ragefire Chasm"},[687]={name="Zul'Farrak"},[689]={name="Blackfathom Deeps"},[691]={name="The Stockade"},[692]={name="Gnomeregan"},[693]={name="Uldaman"},[697]={name="Molten Core"},[698]={name="Zul'Gurub"},[700]={name="Dire Maul"},[705]={name="Blackrock Depths"},[718]={name="Ruins of Ahn'Qiraj"},[719]={name="Onyxia's Lair"},[722]={name="Blackrock Spire",altName="Lower Blackrock Spire",altName2="Upper Blackrock Spire"},[750]={name="Wailing Caverns"},[751]={name="Maraudon"},[756]={name="Blackwing Lair"},[757]={name="The Deadmines"},[761]={name="Razorfen Downs"},[762]={name="Razorfen Kraul"},[763]={name="Scarlet Monastery"},[764]={name="Scholomance"},[765]={name="Shadowfang Keep"},[766]={name="Stratholme"},[767]={name="Temple of Ahn'Qiraj"},[2022]={name="The Temple of Atal'hakkar"},[1244]={name="Valley of Trials"},[1238]={name="Northshire Valley"},[1243]={name="Shadowglen"},[1239]={name="Coldridge Valley"},[1245]={name="Camp Narache"},[1242]={name="Ammen Vale"},[1241]={name="Sunstrider Isle"},[1240]={name="Deathknell"},[1204]={name="Caverns of Time"},[1205]={name="Blackrock Mountain"},[1211]={name="Stillpine Hold"},[1212]={name="Tides' Hollow"},[1213]={name="Night Web's Hollow"},[1214]={name="Gol'Bolar Quarry"},[1215]={name="Coldridge Pass"},[1216]={name="The Grizzled Den"},[1217]={name="Burning Blade Coven"},[1218]={name="Dustwind Cave"},[1219]={name="Skull Rock"},[1220]={name="Fargodeep Mine"},[1222]={name="Jasperlode Mine"},[1223]={name="Amani Catacombs"},[1224]={name="Palemane Rock"},[1225]={name="The Venture Co. Mine"},[1226]={name="Echo Ridge Mine"},[1227]={name="Twilight's Run"},[1228]={name="The Noxious Lair"},[1229]={name="The Gaping Chasm"},[1230]={name="Ban'ethil Barrow Den"},[1232]={name="Fel Rock"},[1233]={name="Shadowthread Cave"},[1234]={name="The Slithering Scar"},[1236]={name="Gold Coast Quarry"},[1237]={name="Jangolode Mine"},[2028]={name="Shadewell Spring"},[2029]={name="Secret Inquisitorial Dungeon"},[2030]={name="Sinister Lair"},[2031]={name="Moonlit Ossuary"}}

        local nameToNewMapID = {}
        for mapID, data in pairs(NewMapDataByID) do
            if data and data.name then nameToNewMapID[data.name] = mapID end
            if data and data.altName then nameToNewMapID[data.altName] = mapID end
            if data and data.altName2 then nameToNewMapID[data.altName2] = mapID end
        end
        
        local OldToNewZoneMap = {
            ["1:2"]={c=1,z=44}, ["1:3"]={c=1,z=182}, ["1:4"]={c=1,z=465}, ["1:6"]={c=1,z=477}, ["1:9"]={c=1,z=43}, ["1:11"]={c=1,z=102}, ["1:12"]={c=1,z=5}, ["1:13"]={c=1,z=142}, ["1:16"]={c=1,z=183}, ["1:17"]={c=1,z=122}, ["1:19"]={c=1,z=242}, ["1:21"]={c=1,z=10}, ["1:27"]={c=1,z=262}, ["1:31"]={c=1,z=82}, ["1:32"]={c=1,z=162}, ["1:33"]={c=1,z=42}, ["1:34"]={c=1,z=12}, ["1:40"]={c=1,z=62}, ["1:44"]={c=1,z=202}, ["1:47"]={c=1,z=282},
            ["1:1"]={c=1,z=1242}, ["1:10"]={c=1,z=382}, ["1:22"]={c=1,z=322}, ["1:24"]={c=1,z=1245}, ["1:25"]={c=1,z=1243}, ["1:35"]={c=1,z=472}, ["1:41"]={c=1,z=363}, ["1:45"]={c=1,z=1244},
            ["1:8"]={c=1,z=1204}, ["1:18"]={c=1,z=751}, ["1:46"]={c=1,z=750}, 
            ["2:1"]={c=2,z=16}, ["2:3"]={c=2,z=17}, ["2:4"]={c=2,z=18}, ["2:5"]={c=2,z=1205}, ["2:6"]={c=2,z=20}, ["2:7"]={c=2,z=30}, ["2:10"]={c=2,z=33}, ["2:12"]={c=2,z=28}, ["2:13"]={c=2,z=35}, ["2:14"]={c=2,z=24}, ["2:16"]={c=2,z=31}, ["2:17"]={c=2,z=463}, ["2:19"]={c=2,z=464}, ["2:22"]={c=2,z=25}, ["2:27"]={c=2,z=36}, ["2:30"]={c=2,z=37}, ["2:32"]={c=2,z=29}, ["2:36"]={c=2,z=22}, ["2:38"]={c=2,z=38}, ["2:40"]={c=2,z=39}, ["2:43"]={c=2,z=27}, ["2:44"]={c=2,z=21}, ["2:47"]={c=2,z=23}, ["2:48"]={c=2,z=40}, ["2:49"]={c=2,z=41},
            ["2:9"]={c=2,z=1239}, ["2:11"]={c=2,z=1240}, ["2:23"]={c=2,z=342}, ["2:29"]={c=2,z=1238}, ["2:35"]={c=2,z=481}, ["2:37"]={c=2,z=302}, ["2:39"]={c=2,z=1241}, ["2:46"]={c=2,z=383},
            ["2:24"]={c=2,z=799}, ["2:31"]={c=2,z=763}, ["2:41"]={c=2,z=757}, ["2:45"]={c=2,z=693}, 
            ["3:1"]={c=3,z=476}, ["3:2"]={c=3,z=466}, ["3:3"]={c=3,z=478}, ["3:4"]={c=3,z=480}, ["3:5"]={c=3,z=474}, ["3:6"]={c=3,z=482}, ["3:7"]={c=3,z=479}, ["3:8"]={c=3,z=468},
            ["4:1"]={c=4,z=487}, ["4:2"]={c=4,z=511}, ["4:3"]={c=4,z=505}, ["4:4"]={c=4,z=489}, ["4:5"]={c=4,z=491}, ["4:6"]={c=4,z=492}, ["4:7"]={c=4,z=542}, ["4:8"]={c=4,z=493}, ["4:9"]={c=4,z=494}, ["4:10"]={c=4,z=496}, ["4:11"]={c=4,z=502}, ["4:12"]={c=4,z=497},
        }

        local discoveries = rawDB.global and rawDB.global.discoveries
        if discoveries then
            print("|cff00ff00LootCollector:|r Performing pre-migration database cleanup...")
            local restrictedRemoved = PurgeByFinderBlacklist(discoveries)
            local cityRemoved = PurgeByCityZones(discoveries)
            local zeroRemoved = PurgeZeroCoordDiscoveries(discoveries)
            print(string.format("|cff00ff00LootCollector:|r Cleanup removed %d blacklisted data, %d city, and %d zero-coord entries.", restrictedRemoved, cityRemoved, zeroRemoved))
        end

        print("|cff00ff00LootCollector:|r Database version " .. tostring(currentSchema) .. " detected. Beginning automatic upgrade to v7...")
        local discoveriesConverted, vendorsConverted, lootedConverted = 0, 0, 0
        local locale = GetLocale()
        local isEnglishClient = (locale == "enUS" or locale == "enGB")
        local playerName = self:normalizeSenderName(UnitName("player"))

        if isEnglishClient then       
            rawDB.global = rawDB.global or {}
            local finalDiscoveries = {}
            local finalVendors = {}
            local discardedCount = 0

            for oldGuid, d in pairs(rawDB.global.discoveries or {}) do            
                 if self:normalizeSenderName(d.fp) == playerName then
                    local c, z, i, x, y = oldGuid:match("^(%d+)%-(%d+)%-(%d+)%-([%-%d%.]+)%-([%-%d%.]+)$")
                    local oldC, oldZ = tonumber(d.c or c), tonumber(d.z or z)
                    
                    local newMapInfo = nil
                    if oldC and oldZ then
                         local key = oldC .. ":" .. oldZ
                         newMapInfo = OldToNewZoneMap[key]
                    end

                    if newMapInfo then
                         local newGuid = GenerateLegacyGUID(newMapInfo.c, newMapInfo.z, i, x, y)
                         d.g, d.c, d.z, d.iz = newGuid, newMapInfo.c, newMapInfo.z, 0 
                         finalDiscoveries[newGuid] = d
                         discoveriesConverted = discoveriesConverted + 1                     
                    else
                        local zoneName = (oldC and oldZ and LegacyZoneData[oldC] and LegacyZoneData[oldC][oldZ])
                        local instanceName = (d.iz and tonumber(d.iz) > 0) and LegacyInstanceData[tonumber(d.iz)]
                        local finalName = zoneName or instanceName
                        local isInstance = not zoneName and instanceName
                        
                        if finalName then
                            local isMysticScroll = (d.il and string.find(d.il, "Mystic Scroll"))
                            local passesSrcCheck = true
                            if isMysticScroll then
                                if not AcceptedLootSrcMS or not d.src or not AcceptedLootSrcMS[d.src] then
                                    passesSrcCheck = false
                                end
                            end

                            if passesSrcCheck then
                                local newMapID = nameToNewMapID[finalName]
                                if newMapID then
                                    local newGuid = GenerateLegacyGUID(oldC, newMapID, i, x, y)
                                    d.g, d.c, d.z, d.iz = newGuid, oldC, newMapID, isInstance and newMapID or 0
                                    finalDiscoveries[newGuid] = d
                                    discoveriesConverted = discoveriesConverted + 1
                                else
                                    discardedCount = discardedCount + 1
                                end
                            else
                                discardedCount = discardedCount + 1
                            end
                        else
                            discardedCount = discardedCount + 1
                        end
                    end
                 end
            end

            for oldGuid, d in pairs(rawDB.global.blackmarketVendors or {}) do            
                 if self:normalizeSenderName(d.fp) == playerName then
                    local prefix, c, z, x, y = oldGuid:match("^(%a+)%-(%d+)%-(%d+)%-([%-%d%.]+)%-([%-%d%.]+)$")
                    if prefix then
                        local oldC, oldZ = tonumber(c), tonumber(d.z or z)
                        
                        local newMapInfo = nil
                        if oldC and oldZ then
                            local key = oldC .. ":" .. oldZ
                            newMapInfo = OldToNewZoneMap[key]
                        end

                        if newMapInfo then
                            local newGuid = prefix .. "-" .. newMapInfo.c .. "-" .. newMapInfo.z .. "-" .. x .. "-" .. y
                            d.g, d.c, d.z = newGuid, newMapInfo.c, newMapInfo.z
                            finalVendors[newGuid] = d
                            vendorsConverted = vendorsConverted + 1
                        else
                            local zoneName = (oldC and oldZ and LegacyZoneData[oldC] and LegacyZoneData[oldC][oldZ])
                            if zoneName then
                                local newMapID = nameToNewMapID[zoneName]
                                if newMapID then
                                    local newGuid = prefix .. "-" .. oldC .. "-" .. newMapID .. "-" .. x .. "-" .. y
                                    d.g, d.c, d.z = newGuid, oldC, newMapID
                                    finalVendors[newGuid] = d
                                    vendorsConverted = vendorsConverted + 1
                                else
                                   discardedCount = discardedCount + 1
                                end
                            else
                                discardedCount = discardedCount + 1
                            end
                        end
                    end
                 end
            end
            
            rawDB.global.discoveries = finalDiscoveries
            rawDB.global.blackmarketVendors = finalVendors
            if discardedCount > 0 then
                print(string.format("|cffff7f00LootCollector:|r Discarded %d of your own unmappable old records during migration.", discardedCount))
            end

        else       
            rawDB.global = rawDB.global or {}
            rawDB.global.discoveries = {}
            rawDB.global.blackmarketVendors = {}
        end

        if _G.LootCollector_OptionalDB_Data and _G.LootCollector_OptionalDB_Data.data then
            local dataStr = _G.LootCollector_OptionalDB_Data.data
            local success, deserialized = pcall(function()
                return LibStub("AceSerializer-3.0"):Deserialize(LibStub("LibDeflate"):DecompressDeflate(LibStub("LibDeflate"):DecodeForPrint(dataStr:match("^!LC1!(.+)$"))))
            end)

            if success and type(deserialized) == "table" then
                local starterDiscoveries = deserialized.discoveries or {}
                local starterVendors = deserialized.blackmarketVendors or {}
                local mergedDiscoveries = 0
                local mergedVendors = 0

                for guid, d in pairs(starterDiscoveries) do
                    local c, z, i, x, y = guid:match("^(%d+)%-(%d+)%-(%d+)%-([%-%d%.]+)%-([%-%d%.]+)$")
                    local oldC, oldZ = tonumber(d.c or c), tonumber(d.z or z)
                    
                    local newMapInfo = nil
                    if oldC and oldZ then
                         local key = oldC .. ":" .. oldZ
                         newMapInfo = OldToNewZoneMap[key]
                    end
                    
                    if newMapInfo then
                         local newGuid = GenerateLegacyGUID(newMapInfo.c, newMapInfo.z, i, x, y)
                         d.g, d.c, d.z, d.iz = newGuid, newMapInfo.c, newMapInfo.z, 0
                         guid = newGuid 
                    end

                    if not rawDB.global.discoveries[guid] then
                        rawDB.global.discoveries[guid] = d 
                        mergedDiscoveries = mergedDiscoveries + 1
                    end
                end
                for guid, d in pairs(starterVendors) do
                    if not rawDB.global.blackmarketVendors[guid] then
                        rawDB.global.blackmarketVendors[guid] = { g=d.guid, c=d.continent, z=d.zoneID, iz=d.instanceID or 0, i=d.itemID, xy=d.coords, il=d.itemLink, q=d.itemQuality or 0, t0=d.timestamp, ls=d.lastSeen, st=d.statusTs, s=d.status, mc=d.mergeCount, fp=d.foundBy_player, o=d.originator, src=d.source, cl=d.class, it=d.itemType or 0, ist=d.itemSubType or 0, dt=d.discoveryType or 0, vendorType=d.vendorType, vendorName=d.vendorName, vendorItems=d.vendorItems }
                        mergedVendors = mergedVendors + 1
                    end
                end
                print(string.format("|cff00ff00LootCollector:|r Starter database has been merged (%d discoveries, %d vendors).", mergedDiscoveries, mergedVendors))
            end
        end

        if rawDB.char then
            for charName, charData in pairs(rawDB.char) do
                if charData and charData.looted then
                    local finalLooted = {}
                    for oldGuid, timestamp in pairs(charData.looted) do
                        local c, z, i, x, y = oldGuid:match("^(%d+)%-(%d+)%-(%d+)%-([%-%d%.]+)%-([%-%d%.]+)$")
                        local converted = false
                        if c and z and i and x and y then
                            local oldC, oldZ = tonumber(c), tonumber(z)
                            
                            local newMapInfo = nil
                            if oldC and oldZ then
                                local key = oldC .. ":" .. oldZ
                                newMapInfo = OldToNewZoneMap[key]
                            end
                            
                            if newMapInfo then
                                local newGuid = GenerateLegacyGUID(newMapInfo.c, newMapInfo.z, i, x, y)
                                finalLooted[newGuid] = timestamp
                                lootedConverted = lootedConverted + 1
                                converted = true
                            else
                                local zoneName = (oldC and oldZ and LegacyZoneData[oldC] and LegacyZoneData[oldC][oldZ])
                                if zoneName then
                                    local newMapID = nameToNewMapID[zoneName]
                                    if newMapID then
                                        local newGuid = GenerateLegacyGUID(oldC, newMapID, i, x, y)
                                        finalLooted[newGuid] = timestamp
                                        lootedConverted = lootedConverted + 1
                                        converted = true
                                    end
                                end
                            end
                        end
                        -- Never drop unmatched looted GUIDs during migration.
                        if not converted then
                            finalLooted[oldGuid] = timestamp
                        end
                    end
                    charData.looted = finalLooted
                end
            end
        end
        
        rawDB._schemaVersion = 7
        rawDB.schemaVersion = nil
        currentSchema = 7
        print(string.format("|cff00ff00LootCollector:|r V7 Upgrade complete! Personal: %d discoveries, %d vendors. Looted: %d records.", discoveriesConverted, vendorsConverted, lootedConverted))
        StaticPopup_Show("LOOTCOLLECTOR_MIGRATION_RELOAD")
    end

    
    
    
    if currentSchema == 7 then
        print("|cff00ff00LootCollector:|r Upgrading database to v8 (High-Precision Coordinates & Unified Instance Tracking)...")
        
        
        local function _lcHex32(u)
            local n = tonumber(u) or 0
            local hi = math.floor(n / 65536)
            local lo = n % 65536
            return string.format("%04x%04x", hi, lo)
        end

        local function _lcFNV1a32(s)
            local hash = 2166136261
            for i = 1, #s do
                hash = bit.bxor(hash, string.byte(s, i))
                hash = (hash * 16777619) % 4294967296
            end
            return hash
        end

        local function _lcIdentityString(tbl)
            return table.concat({
                tostring(tbl.v or 5),
                tostring(tbl.op or "DISC"),
                tostring(tbl.c or 0),
                tostring(tbl.z or 0),
                tostring(tbl.iz or 0),
                tostring(tbl.i or 0),
                string.format("%.4f", tonumber(tbl.x) or 0),
                string.format("%.4f", tonumber(tbl.y) or 0),
                "0", 
            }, "|")
        end

        local guidMap = {}
        local discoveriesConverted = 0
        local vendorsConverted = 0
        local lootedConverted = 0
        local amnestyGranted = 0
        
        rawDB.global = rawDB.global or {}
        rawDB.global.deletedCache = {} 
        
        local tnow = time()
        
        if rawDB.global.realms then
            for realmKey, realmData in pairs(rawDB.global.realms) do
                
                if realmData.discoveries then
                    local newDiscoveries = {}
                    for oldGuid, d in pairs(realmData.discoveries) do
                        
                        
                        local age = tnow - (tonumber(d.ls) or 0)
                        
                        if age >= (120 * 86400) then
                            
                            d.ls = tnow - (113 * 86400)
                            d.s = "STALE"
                            d.st = tnow
                            amnestyGranted = amnestyGranted + 1
                        elseif d.s == "STALE" or age >= (90 * 86400) then
                            
                            d.ls = tnow - (83 * 86400)
                            d.s = "FADING"
                            d.st = tnow
                            amnestyGranted = amnestyGranted + 1
                        elseif d.s == "FADING" or age >= (30 * 86400) then
                            
                            d.ls = (tonumber(d.ls) or tnow) + (7 * 86400)
                            
                            if (tnow - d.ls) < (30 * 86400) then
                                d.ls = tnow - (30 * 86400) 
                            end
                            amnestyGranted = amnestyGranted + 1
                        end
                        
                        local iz = tonumber(d.iz) or 0
                        local x = d.xy and d.xy.x or 0
                        local y = d.xy and d.xy.y or 0
                        
                        local newGuid = self:GenerateGUID(d.c, d.z, iz, d.i, x, y)
                        d.g = newGuid
                        d.mk = nil 
                        
                        local payload = {
                            v = 5, op = "DISC", c = d.c, z = d.z, iz = iz, i = d.i,
                            x = self:Round4(x), y = self:Round4(y)
                        }
                        d.mid = _lcHex32(_lcFNV1a32(_lcIdentityString(payload)))
                        
                        newDiscoveries[newGuid] = d
                        guidMap[oldGuid] = newGuid
                        discoveriesConverted = discoveriesConverted + 1
                    end
                    realmData.discoveries = newDiscoveries
                end
                
                
                if realmData.blackmarketVendors then
                    local newVendors = {}
                    for oldGuid, d in pairs(realmData.blackmarketVendors) do
                        local iz = tonumber(d.iz) or 0
                        local x = d.xy and d.xy.x or 0
                        local y = d.xy and d.xy.y or 0
                        
                        local vType = d.vendorType
                        if not vType then
                            local i = tonumber(d.i) or 0
                            vType = (i >= -499999 and i <= -400000) and "MS" or "BM"
                        end
                        
                        local newGuid = self:GenerateVendorGUID(vType, d.c, d.z, iz, x, y)
                        d.g = newGuid
                        d.mk = nil
                        
                        local payload = {
                            v = 5, op = "DISC", c = d.c, z = d.z, iz = iz, i = d.i,
                            x = self:Round4(x), y = self:Round4(y)
                        }
                        d.mid = _lcHex32(_lcFNV1a32(_lcIdentityString(payload)))
                        
                        newVendors[newGuid] = d
                        guidMap[oldGuid] = newGuid
                        vendorsConverted = vendorsConverted + 1
                    end
                    realmData.blackmarketVendors = newVendors
                end
            end
        end
        
        
        if rawDB.char then
            for charName, charData in pairs(rawDB.char) do
                if charData and charData.looted then
                    local newLooted = {}
                    for oldGuid, timestamp in pairs(charData.looted) do
                        local newGuid = guidMap[oldGuid]
                        if newGuid then
                            newLooted[newGuid] = timestamp
                            lootedConverted = lootedConverted + 1
                        else
                            newLooted[oldGuid] = timestamp 
                        end
                    end
                    charData.looted = newLooted
                end
            end
        end
        
        rawDB._schemaVersion = 8
        rawDB.schemaVersion = nil
        currentSchema = 8
        print(string.format("|cff00ff00LootCollector:|r V8 Upgrade complete! %d Discoveries, %d Vendors, %d Looted records migrated.", discoveriesConverted, vendorsConverted, lootedConverted))
        if amnestyGranted > 0 then
            print(string.format("|cff00ff00LootCollector:|r Applied V8 Amnesty to %d legacy records, extending their decay timers by 7 days.", amnestyGranted))
        end
        StaticPopup_Show("LOOTCOLLECTOR_MIGRATION_RELOAD")
    end
end

local function ApplyAscensionHooks()
    
    if _G.ClassInfoUtil and type(_G.ClassInfoUtil.GetSpecName) == "function" and not _G.ClassInfoUtil._LCHooked then
        _G.ClassInfoUtil.GetSpecName = function(class, spec)
            if not class or not spec then return "" end
            local ok, info = pcall(_G.C_ClassInfo.GetSpecInfo, class, spec)
            if ok and info and info.Name then
                return info.Name
            end
            return ""
        end
        _G.ClassInfoUtil._LCHooked = true
    end

    
    if type(_G.GameTooltip_GetEnchantRequirements) == "function" and not _G._LCEnchantReqHooked then
        local origReq = _G.GameTooltip_GetEnchantRequirements
        _G.GameTooltip_GetEnchantRequirements = function(...)
            local ok, res = pcall(origReq, ...)
            if ok then return res end
            return nil
        end
        _G._LCEnchantReqHooked = true
    end
end

ApplyAscensionHooks()

function LootCollector:EnsureDatabaseInitialized()
    if self.databaseInitialized then return true end

    local realm = GetRealmName()
    if not realm or realm == "" or realm == "Unknown Realm" then
        return false
    end

    self:ActivateRealmBucket()
    self.databaseInitialized = true

    local discoveries = self:GetDiscoveriesDB()
    local hasLiveDiscovery = false
    if discoveries then
        for _, rec in pairs(discoveries) do
            if type(rec) == "table" and not rec.vendorType then
                local s = rec.s
                if s == "CONFIRMED" or s == "UNCONFIRMED" or s == nil then
                    hasLiveDiscovery = true
                    break
                end
            end
        end
    end
    local isNewDatabase = not hasLiveDiscovery
    local realmBucket = self.db.global.realms and self.activeRealmKey and self.db.global.realms[self.activeRealmKey]

    if isNewDatabase then
        -- Per-realm: an empty Vol'jin bucket must merge even if Rexxar already
        -- set profile.offeredOptionalDB on the shared Default profile.
        local loaded, reason = LoadAddOn("LootCollector_StarterDB")
        local dbData = _G.LootCollector_OptionalDB_Data
        if loaded and type(dbData) == "table" and dbData.version and dbData.data then
            print("|cff00ff00LootCollector:|r No confirmed discoveries on this realm. Automatically merging starter database...")
            local ImportExport = self:GetModule("ImportExport", true)
            if ImportExport and ImportExport.ApplyImportString then
                ImportExport:ApplyImportString(dbData.data, "MERGE", false, true, true)
            end
            if realmBucket then
                realmBucket.starterMergedVersion = dbData.version
            end
            if self.db.profile then
                self.db.profile.offeredOptionalDB = dbData.version
            end
            discoveries = self:GetDiscoveriesDB()
            if (not discoveries) or (not next(discoveries)) then
                print("|cffff7f00LootCollector:|r Starter database merge ran but this realm still has no discoveries. Open /lcv and use Merge Starter Database, or /lcimport.")
            end
        else
            local name, _, _, enabled, loadable, infoReason = GetAddOnInfo("LootCollector_StarterDB")
            local why = reason or infoReason
            if why == "MISSING" or not name or name == "" then
                print("|cffff7f00LootCollector:|r No discoveries on this realm. Install LootCollector_StarterDB, enable it at character select, then /reload.")
            elseif why == "DISABLED" or enabled == false or (loadable == false and enabled ~= true) then
                print("|cffff7f00LootCollector:|r No discoveries on this realm. Enable LootCollector_StarterDB at character select, then /reload.")
            else
                print(string.format("|cffff7f00LootCollector:|r No discoveries on this realm. Starter database could not be merged. Reason: %s", tostring(why or "unknown")))
            end
        end
    else
        local name, title, notes, enabled, loadable, reason = GetAddOnInfo("LootCollector_StarterDB")
        if name and loadable then
            local starterVersion = GetAddOnMetadata("LootCollector_StarterDB", "Version")
            
            if starterVersion and self.db.profile and self.db.profile.offeredOptionalDB ~= starterVersion then
                local loaded = LoadAddOn("LootCollector_StarterDB")
                if loaded and _G.LootCollector_OptionalDB_Data then
                    local dbData = _G.LootCollector_OptionalDB_Data
                    self:ScheduleAfter(5, function()
                        StaticPopup_Show("LOOTCOLLECTOR_OPTIONAL_DB_UPDATE", starterVersion, dbData.changelog or "No changes listed.", starterVersion)
                    end)
                end
            end
        end
    end

    return true
end

function LootCollector:OnInitialize()
    
    self:PreInitializeMigration()

    if self.LEGACY_MODE_ACTIVE then
        print("|cffff0000LootCollector is in Legacy Mode!|r")
        print("|cffffff00Your database is from an older version and needs to be updated.|r")
        print(" - Please |cffff7f00/reload|r your UI to trigger the automatic update.")
        return 
    end

    self.db = LibStub("AceDB-3.0"):New("LootCollectorDB_Asc", dbDefaults, true)

    -- Drop the in-session item-cache queue before AceDB serializes on logout.
    -- The queue can be thousands of IDs and is rebuilt as needed next login.
    if self.db.RegisterCallback then
        self.db.RegisterCallback(self, "OnDatabaseShutdown", function()
            if LootCollector.db and LootCollector.db.global then
                LootCollector.db.global.cacheQueue = {}
                local Core = LootCollector:GetModule("Core", true)
                if Core then
                    if Core._queueSet then wipe(Core._queueSet) end
                    Core._queueSetBuilt = false
                end
            end
        end)
    end

    if _G.LootCollectorDB_Asc then
        local rawDB = _G.LootCollectorDB_Asc
        if rawDB._schemaVersion == nil and rawDB.schemaVersion ~= nil then
            rawDB._schemaVersion = tonumber(rawDB.schemaVersion) or 0
        end
        rawDB.schemaVersion = nil
        if (tonumber(rawDB._schemaVersion) or 0) < 8 then
            rawDB._schemaVersion = 8
        end
    end

    self.channelReady = false
    self.name         = "LootCollector"
    self.Version      = "1.0.5"
    -- Build stamp: NOT part of the comm-version string (which other
    -- clients' version filters compare); purely for humans to verify which
    -- fix pass is actually installed (minimap tooltip + /lcvendor).
    self.BuildStamp   = "1.0.5"

    local Constants = self:GetModule("Constants", true)
    if Constants and Constants.GetDefaultChannel then
        self.chatChannel = Constants:GetDefaultChannel()
        self.addonPrefix = Constants:GetDefaultPrefix()
    else
        self.chatChannel = "BBLC25C"
        self.addonPrefix = "BBLC25AM"
    end

    local Comm = self:GetModule("Comm", true)
    if Comm then
        Comm.addonPrefix = self.addonPrefix
        Comm.channelName = self.chatChannel
    end

    
    self.notifiedNewVersion = nil

    self.db.char        = self.db.char or {}
    self.db.char.looted = self.db.char.looted or {}
    self.db.char.lootedBackup = self.db.char.lootedBackup or {}
    self.db.char.hidden = self.db.char.hidden or {}
    self.db.char.favorites = self.db.char.favorites or {}
    self.db.char.mapFilters = self.db.char.mapFilters or {}
    self.db.global = self.db.global or {}
    self.db.global.lootedArchive = self.db.global.lootedArchive or {}
    self.db.global.lootedHighWater = self.db.global.lootedHighWater or {}
    self:SeedLootedBackupFromLive()
    self:SeedLootedArchiveFromLayers()
    self:UpdateLootedHighWater()
    if self.db.profile.perCharacterFavorites == nil then
        self.db.profile.perCharacterFavorites = false
    end
    self.db.profile.favorites = self.db.profile.favorites or {}

    -- Floor saved version gate at MIN_COMPATIBLE_VERSION (1.0.0). An old
    -- override of 0.8.5 would still accept beta-0.8.5 packets.
    self.db.profile.sharing = self.db.profile.sharing or {}
    do
        local override = self.db.profile.sharing.minVersionGateOverride
        local minVer = (Constants and Constants.MIN_COMPATIBLE_VERSION) or "1.0.0"
        if override and override ~= "" and Constants and Constants.CompareVersions
            and Constants:CompareVersions(override, minVer) < 0 then
            self.db.profile.sharing.minVersionGateOverride = nil
        end
    end

    -- Migrate legacy "Filter by Deep Filter" into Filter Map (once).
    local cmf = self.db.char.mapFilters
    if cmf.useDeepFilter and not cmf._migratedUseDeepFilterToFilterMap then
        cmf.applyViewerFiltersOnMap = true
        cmf.useDeepFilter = nil
        cmf._migratedUseDeepFilterToFilterMap = true
    end
    if cmf.applyViewerFiltersOnMap == nil then
        cmf.applyViewerFiltersOnMap = false
    end

    self:EnsureDatabaseInitialized()
    
    SLASH_LootCollectorARROW1 = "/lcarrow"
    SlashCmdList["LootCollectorARROW"] = function(msg)
        local Arrow = self:GetModule("Arrow", true)
        if Arrow and Arrow.SlashCommandHandler then
            Arrow:SlashCommandHandler(msg)
        else
            print("|cffff7f00LootCollector:|r Arrow module not available.")
        end
    end

    SLASH_LOOTCOLLECTORTOGGLE1 = "/lctoggle"
    SlashCmdList["LOOTCOLLECTORTOGGLE"] = function()
        LootCollector:ToggleAllDiscoveries()
    end
    
    
    SLASH_LOOTCOLLECTORPAUSE1 = "/lcpause"
    SlashCmdList["LOOTCOLLECTORPAUSE"] = function()
        LootCollector:TogglePause()
    end
    
    SLASH_LOOTCOLLECTORCCQ1 = "/lcccq"
    SlashCmdList["LOOTCOLLECTORCCQ"] = function()
        if LootCollector.db and LootCollector.db.global then
            local queueSize = (LootCollector.db.global.cacheQueue and #LootCollector.db.global.cacheQueue) or 0
            LootCollector.db.global.cacheQueue = {}
            local Core = LootCollector:GetModule("Core", true)
            if Core and Core._queueSet then
                 wipe(Core._queueSet)
            end
            print(string.format("|cff00ff00LootCollector:|r Cleared %d items from the background cache queue.", queueSize))
        else
            print("|cffff7f00LootCollector:|r Database not ready.")
        end
    end
	
	SLASH_LOOTCOLLECTORCZFIX1 = "/lcczfix"
    SlashCmdList["LOOTCOLLECTORCZFIX"] = function()
        local Core = LootCollector:GetModule("Core", true)
        if Core and Core.FixLegacyZoneIDs then
            LootCollector.db.global.legacyZoneFixV2 = false
            Core:FixLegacyZoneIDs()
        else
             print("|cffff7f00LootCollector:|r Core module not available.")
        end
    end

    self:InitializeStarterDBLookup()
end

function LootCollector:InitializeStarterDBLookup()
    if self.StarterDBCoords then return end
    self.StarterDBItemZones = self.StarterDBItemZones or {}
    self.StarterDBCoords = {}
    
    local loaded = LoadAddOn("LootCollector_StarterDB")
    if loaded and _G.LootCollector_OptionalDB_Data and type(_G.LootCollector_OptionalDB_Data) == "table" then
        local dataStr = _G.LootCollector_OptionalDB_Data.data
        if dataStr and dataStr ~= "" then
            local body = dataStr:match("^!LC1!(.+)$")
            if body then
                local LibDeflate = LibStub:GetLibrary("LibDeflate", true)
                local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0", true)
                if LibDeflate and AceSerializer then
                    local bytes = LibDeflate:DecodeForPrint(body)
                    if bytes then
                        local unz = LibDeflate:DecompressDeflate(bytes)
                        if unz then
                            local ok, _, tbl = pcall(AceSerializer.Deserialize, AceSerializer, unz)
                            if ok and type(tbl) == "table" and tbl.discoveries then
                                for _, d in pairs(tbl.discoveries) do
                                    if d.itemID and d.zoneID then
                                        local itemID = tonumber(d.itemID)
                                        local zoneID = tonumber(d.zoneID)
                                        if itemID and zoneID then
                                            self.StarterDBItemZones[itemID] = self.StarterDBItemZones[itemID] or {}
                                            self.StarterDBItemZones[itemID][zoneID] = true
                                            self.StarterDBZoneCounts = self.StarterDBZoneCounts or {}
                                            self.StarterDBZoneCounts[itemID] = self.StarterDBZoneCounts[itemID] or {}
                                            self.StarterDBZoneCounts[itemID][zoneID] = (self.StarterDBZoneCounts[itemID][zoneID] or 0) + 1
                                            local x = d.coords and tonumber(d.coords.x)
                                            local y = d.coords and tonumber(d.coords.y)
                                            if x and y and x > 0 and y > 0 and x <= 1 and y <= 1 then
                                                self.StarterDBCoords[itemID] = self.StarterDBCoords[itemID] or {}
                                                local prev = self.StarterDBCoords[itemID][zoneID]
                                                local mc = tonumber(d.mergeCount) or 1
                                                local ZoneList = self:GetModule("ZoneList", true)
                                                local zInfo = ZoneList and ZoneList.MapDataByID and ZoneList.MapDataByID[zoneID]
                                                local c = (zInfo and tonumber(zInfo.continentID)) or tonumber(d.continent)
                                                if not prev or mc >= (prev.mc or 0) then
                                                    self.StarterDBCoords[itemID][zoneID] = {
                                                        c = c,
                                                        x = x,
                                                        y = y,
                                                        mc = mc,
                                                    }
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if self.FilterStarterDBLeftoverZones then
        self:FilterStarterDBLeftoverZones()
    end
end


LootCollector.isHibernating = false

function LootCollector:IsPaused()
    return self.isHibernating
end

function LootCollector:EvaluateAutoPause()
    if not (self.db and self.db.char) then return end
    
    local c = self.db.char
    local shouldHibernate = c.paused 

    if not shouldHibernate and c.autoPauseInRaidGroup then
        if GetNumRaidMembers() > 0 then
            shouldHibernate = true
        end
    end

    if not shouldHibernate then
        local inInstance, instanceType = IsInInstance()
        if inInstance then
            if c.autoPauseInBG and (instanceType == "pvp" or instanceType == "arena") then
                shouldHibernate = true
            elseif c.autoPauseInRaidInstance and instanceType == "raid" then
                shouldHibernate = true
            end
        end
    end

    if shouldHibernate and not self.isHibernating then
        self:EnterHibernation()
    elseif not shouldHibernate and self.isHibernating then
        self:ExitHibernation()
    end
end

function LootCollector:EnterHibernation()
    self.isHibernating = true
    print("|cffff7f00LootCollector:|r Hibernation Mode |cffff0000ON|r. All processing, map icons, and local detection are stopped.")
    
    
    local Comm = self:GetModule("Comm", true)
    if Comm then
        if Comm.StopBackgroundProcessing then
            Comm:StopBackgroundProcessing()
        else
            if Comm._rateLimitQueue then wipe(Comm._rateLimitQueue) end
            if Comm._delayQueue then wipe(Comm._delayQueue) end
            if Comm._incomingMessageQueue then wipe(Comm._incomingMessageQueue) end
            if Comm.rawBuffer then wipe(Comm.rawBuffer) end
        end
    end

    local Reinforce = self:GetModule("Reinforce", true)
    if Reinforce and Reinforce.PauseBackground then
        Reinforce:PauseBackground()
    end
    
    
    local Core = self:GetModule("Core", true)
    if Core then
        if Core.pendingBroadcasts then wipe(Core.pendingBroadcasts) end
        if Core.StopCaching then Core:StopCaching() end
    end
    
    
    local Arrow = self:GetModule("Arrow", true)
    if Arrow and Arrow.Hide then Arrow:Hide() end

    
    local Map = self:GetModule("Map", true)
    if Map then
        if Map.StopMinimapTicker then Map:StopMinimapTicker() end
        Map.cacheIsDirty = true
        if Map.Update and WorldMapFrame and WorldMapFrame:IsShown() then Map:Update() end
        if Map.UpdateMinimap then Map:UpdateMinimap() end
    end
end

function LootCollector:ExitHibernation()
    self.isHibernating = false
    print("|cff00ff00LootCollector:|r Hibernation Mode |cff00ff00OFF|r. Normal functionality resumed.")
    
    
    local Core = self:GetModule("Core", true)
    if Core and Core.EnsureCachePump then Core:EnsureCachePump() end

    local Comm = self:GetModule("Comm", true)
    if Comm and Comm.StartBackgroundProcessing then
        Comm:StartBackgroundProcessing()
    end

    local Reinforce = self:GetModule("Reinforce", true)
    if Reinforce and Reinforce.ResumeBackground then
        Reinforce:ResumeBackground()
    end
    
    
    local Arrow = self:GetModule("Arrow", true)
    local autoTrack = self.db.char and self.db.char.mapFilters and self.db.char.mapFilters.autoTrackNearest
    if Arrow and Arrow.Show and autoTrack then
        Arrow:Show()
    end

    
    local Map = self:GetModule("Map", true)
    if Map then
        Map.cacheIsDirty = true
        if Map.Update and WorldMapFrame and WorldMapFrame:IsShown() then Map:Update() end
        if Map.UpdateMinimap then Map:UpdateMinimap() end
    end
end

function LootCollector:TogglePause()
    if not (self.db and self.db.char) then return end
    self.db.char.paused = not self.db.char.paused
    self:EvaluateAutoPause()
end

function LootCollector:ToggleAllDiscoveries()
    if not (self.db and self.db.char and self.db.char.mapFilters) then return end
    self.db.char.mapFilters.hideAll = not self.db.char.mapFilters.hideAll
    
    if self.db.char.mapFilters.hideAll then
        print("|cffff7f00LootCollector:|r All discoveries are now |cffff0000HIDDEN|r on the Map and Minimap.")
    else
        print("|cff00ff00LootCollector:|r All discoveries are now |cff00ff00SHOWN|r on the Map and Minimap.")
    end
    
    local Map = self:GetModule("Map", true)
    if Map then
        if Map.Update and WorldMapFrame and WorldMapFrame:IsShown() then
            Map:Update()
        end
        if Map.UpdateMinimap then
            Map:UpdateMinimap()
        end
    end
end

function LootCollector:MaybeShowWelcomeTips()
    if self.LEGACY_MODE_ACTIVE then return end
    if not (self.db and self.db.profile) then return end
    if self.db.profile.hideLootCollectorWelcome then return end
    if StaticPopup_Visible and StaticPopup_Visible("LOOTCOLLECTOR_WELCOME") then return end
    StaticPopup_Show("LOOTCOLLECTOR_WELCOME")
end

function LootCollector:MaybeShowPublicChannelPrompt()
    if self.LEGACY_MODE_ACTIVE then return end
    if not (self.db and self.db.profile) then return end
    local p = self.db.profile
    if p.promptedPublicChannelSync then return end
    local sharing = p.sharing or {}
    if sharing.enabled == false then return end
    if sharing.publicChannelEnabled then return end
    if StaticPopup_Visible and (
        StaticPopup_Visible("LOOTCOLLECTOR_WELCOME") or
        StaticPopup_Visible("LOOTCOLLECTOR_PUBLIC_CHANNEL_PROMPT") or
        StaticPopup_Visible("LOOTCOLLECTOR_OPTIONAL_DB_UPDATE") or
        StaticPopup_Visible("LOOTCOLLECTOR_MIGRATION_RELOAD")
    ) then
        self:ScheduleAfter(3.0, function()
            LootCollector:MaybeShowPublicChannelPrompt()
        end)
        return
    end
    StaticPopup_Show("LOOTCOLLECTOR_PUBLIC_CHANNEL_PROMPT")
end

function LootCollector:IsZoneIgnored()
    if not (self.db and self.db.profile and self.db.profile.ignoreZones) then return false end
    local zoneName = GetRealZoneText()
    return zoneName and self.db.profile.ignoreZones[zoneName]
end

function LootCollector:DelayedChannelInit()
    -- Leave immediately so a saved JoinPermanentChannel auto-join cannot
    -- steal a low chat number before Ascension/Newcomers. Legacy name is
    -- the old typo; also leave the live channel name.
    pcall(LeaveChannelByName, "BBLCC25")
    pcall(LeaveChannelByName, self.chatChannel or "BBLC25C")
    local Comm = self:GetModule("Comm", true)
    if not Comm then return end
    local DELAY_SECONDS = 20.0
    self:ScheduleAfter(DELAY_SECONDS, function()
        LootCollector.channelReady = true
        if LootCollector.db and LootCollector.db.profile.sharing.enabled and not LootCollector:IsZoneIgnored() then
            if Comm.EnsureChannelJoined then
                Comm:EnsureChannelJoined()
            end
        end
    end)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function LootCollector:OnEnable()   
    local Map = self:GetModule("Map", true)
    if Map then 
        self:RegisterEvent("WORLD_MAP_UPDATE", function() 
            if WorldMapFrame and WorldMapFrame:IsShown() then Map:Update() end 
        end) 
    end
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, ...)
        self:EnsureDatabaseInitialized()
        self:DelayedChannelInit()
        
        self:EvaluateAutoPause()

        -- After DB is ready; before the optional Starter DB update prompt (~5s).
        if not self._welcomeTipsScheduled then
            self._welcomeTipsScheduled = true
            self:ScheduleAfter(2.5, function()
                LootCollector:MaybeShowWelcomeTips()
            end)
            self:ScheduleAfter(8.0, function()
                LootCollector:MaybeShowPublicChannelPrompt()
            end)
        end
        self:SchedulePrestigeLevelCheck()
    end)
    
    
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "EvaluateAutoPause")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "EvaluateAutoPause")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "EvaluateAutoPause")
    self:RegisterEvent("PLAYER_LEVEL_UP", function(_, newLevel)
        local level = tonumber(newLevel) or (UnitLevel and UnitLevel("player"))
        local stored = LootCollector.db and LootCollector.db.char and tonumber(LootCollector.db.char.lastSeenLevel)
        if stored and level and level < stored then
            LootCollector:CheckPrestigeLevelDrop()
        else
            LootCollector:RememberPlayerLevel(level)
        end
    end)
end

function LootCollector:OnDisable()
    self:UnregisterAllEvents()
end

function LootCollector:SyncInvalidSendersWithBlockList()
    if not (self.db and self.db.profile) then return end
    local profile = self.db.profile
    local blockList = profile.sharing and profile.sharing.blockList or {}
    local invalidSenders = profile.invalidSenders
    
    if invalidSenders then
        for name, track in pairs(invalidSenders) do
            
            if track.permanent and not blockList[name] then
                
                invalidSenders[name] = nil
            end
        end
    end
end

SLASH_LCCLEANUP1 = "/lccdb"
SlashCmdList["LCCLEANUP"] = function()
    local Core = LootCollector:GetModule("Core", true)
    if Core and Core.RunManualDatabaseCleanup then
        Core:RunManualDatabaseCleanup()
    else
        print("|cffff7f00LootCollector:|r Core module not available.")
    end
end

-- Membership test against the curated WorldforgedList (accepts upgraded /
-- variant IDs by normalizing through GetBaseItemID). Used by Detect to
-- qualify untagged vanity Worldforged items, and by UI code that needs to
-- know whether an item belongs to the dev-provided list.
function LootCollector:IsWorldforgedListItem(id)
    id = tonumber(id)
    if not id or id == 0 then return false end
    local set = self._wfListSet
    if not set then
        set = {}
        if self.WorldforgedList then
            for _, itemID in ipairs(self.WorldforgedList) do
                set[itemID] = true
            end
        end
        self._wfListSet = set
    end
    if set[id] then return true end
    local baseID = self:GetBaseItemID(id)
    return set[baseID] == true
end

-- True for pins we are allowed to store: vendors, Mystic Scrolls on MS realms,
-- or Worldforged (list, StarterDB, or tooltip). Not quality/Heroic/named-drop.
-- opts: vendorType, il
function LootCollector:IsTrackableDiscovery(itemID, name, dt, opts)
    opts = opts or {}
    local Constants = self:GetModule("Constants", true)
    local types = Constants and Constants.DISCOVERY_TYPE
    local BM = types and types.BLACKMARKET
    local MS = types and types.MYSTIC_SCROLL

    if opts.vendorType or (BM and dt == BM) then
        return true
    end

    itemID = tonumber(itemID) or 0
    if (not name or name == "") and opts.il and type(opts.il) == "string" then
        name = opts.il:match("%[(.-)%]")
    end
    if (not name or name == "") and itemID > 0 then
        name = select(1, GetItemInfo(itemID))
    end
    name = name or ""

    local isMSName = name ~= "" and string.find(name, "Mystic Scroll", 1, true) ~= nil
    if (MS and dt == MS) or isMSName then
        if not (Constants and Constants.HasMysticScrolls and Constants:HasMysticScrolls()) then
            return false
        end
        if self.ignoreList and self.ignoreList[name] then return false end
        if self.sourceSpecificIgnoreList and self.sourceSpecificIgnoreList[name] then return false end
        return isMSName
    end

    if itemID > 0 then
        if self.IsWorldforgedListItem and self:IsWorldforgedListItem(itemID) then
            return true
        end
        local base = (self.GetBaseItemID and self:GetBaseItemID(itemID, name ~= "" and name or opts.il)) or itemID
        if self.StarterDBItemZones and (self.StarterDBItemZones[itemID] or self.StarterDBItemZones[base]) then
            return true
        end
        local Scanner = self:GetModule("Scanner", true)
        if Scanner and Scanner.GetItemData then
            local data = Scanner:GetItemData(itemID, opts.il)
            if data and data.isWF then return true end
        end
    end
    return false
end

function LootCollector:_IsKnownWorldforgedBase(id)
    id = tonumber(id)
    if not id or id == 0 then return false end
    if self.WorldforgedUpgrades and self.WorldforgedUpgrades[id] then
        return true
    end
    local set = self._wfListSet
    if not set then
        set = {}
        if self.WorldforgedList then
            for _, itemID in ipairs(self.WorldforgedList) do
                if itemID then set[itemID] = true end
            end
        end
        self._wfListSet = set
    end
    return set[id] == true
end

local function ExtractItemNameFromHint(hint)
    if type(hint) ~= "string" or hint == "" then return nil end
    local fromLink = hint:match("%[(.-)%]")
    if fromLink then return fromLink end
    if not hint:find("|Hitem:", 1, true) then
        return hint
    end
    return nil
end

-- StarterDB lists verified zones per base item. No entry means unrestricted.
-- An entry whose zone is missing means the pin is off-list and must be dropped.
-- CoordAuthority, if present for the item, is exhaustive and wins over StarterDB.
function LootCollector:IsStarterDBZoneAllowed(itemID, zoneID)
    itemID = tonumber(itemID)
    zoneID = tonumber(zoneID)
    if not itemID or not zoneID then return true end
    if self.IsCoordAuthorityZoneAllowed and not self:IsCoordAuthorityZoneAllowed(itemID, zoneID) then
        return false
    end
    local allowed = self.StarterDBItemZones and self.StarterDBItemZones[itemID]
    if not allowed then return true end
    return allowed[zoneID] == true or allowed[tostring(zoneID)] == true
end

LootCollector.LEFTOVER_XY_EPS = 0.02

local LEFTOVER_CONTINENT_MAPS = {
    [14] = true, [15] = true, [467] = true, [486] = true,
}
local LEFTOVER_CITY_MAPS = {
    [302] = true, [322] = true, [342] = true, [363] = true,
    [382] = true, [383] = true, [472] = true, [481] = true,
    [482] = true, [505] = true,
}

function LootCollector:IsLeftoverXyMatch(x1, y1, x2, y2)
    x1, y1 = tonumber(x1) or 0, tonumber(y1) or 0
    x2, y2 = tonumber(x2) or 0, tonumber(y2) or 0
    local eps = self.LEFTOVER_XY_EPS or 0.02
    return math.abs(x1 - x2) < eps and math.abs(y1 - y2) < eps
end

function LootCollector:IsLeftoverMicroMap(zoneID)
    zoneID = tonumber(zoneID) or 0
    if zoneID >= 1211 and zoneID <= 1245 then return true end
    if LEFTOVER_CONTINENT_MAPS[zoneID] then return true end
    if LEFTOVER_CITY_MAPS[zoneID] then return true end
    return false
end

function LootCollector:StarterDBZoneCount(itemID, zoneID)
    itemID, zoneID = tonumber(itemID), tonumber(zoneID)
    if not itemID or not zoneID then return 0 end
    local counts = self.StarterDBZoneCounts and self.StarterDBZoneCounts[itemID]
    if counts and counts[zoneID] then return tonumber(counts[zoneID]) or 0 end
    if self.GetBaseItemID then
        local base = self:GetBaseItemID(itemID)
        if base and base ~= itemID then
            counts = self.StarterDBZoneCounts and self.StarterDBZoneCounts[base]
            if counts and counts[zoneID] then return tonumber(counts[zoneID]) or 0 end
        end
    end
    return 0
end

-- Higher is better. CoordAuthority > StarterDB count > outdoor > liveCount.
function LootCollector:LeftoverKeepRank(itemID, zoneID, liveCount)
    itemID, zoneID = tonumber(itemID), tonumber(zoneID)
    liveCount = tonumber(liveCount) or 0
    local ca = 0
    if zoneID and self.GetCoordAuthorityEntry and self:GetCoordAuthorityEntry(itemID, zoneID) then
        ca = 1
    end
    local starter = self:StarterDBZoneCount(itemID, zoneID)
    local outdoor = (zoneID and not self:IsLeftoverMicroMap(zoneID)) and 1 or 0
    return ca, starter, outdoor, liveCount
end

function LootCollector:LeftoverKeepBetter(itemID, zoneA, liveA, zoneB, liveB)
    local a1, a2, a3, a4 = self:LeftoverKeepRank(itemID, zoneA, liveA)
    local b1, b2, b3, b4 = self:LeftoverKeepRank(itemID, zoneB, liveB)
    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    if a3 ~= b3 then return a3 > b3 end
    if a4 ~= b4 then return a4 > b4 end
    return (tonumber(zoneA) or 0) < (tonumber(zoneB) or 0)
end

function LootCollector:FilterStarterDBLeftoverZones()
    local coords = self.StarterDBCoords
    local allowed = self.StarterDBItemZones
    if not coords or not allowed then return end

    for itemID, byZone in pairs(coords) do
        if type(byZone) == "table" then
            local zones = {}
            for z, rec in pairs(byZone) do
                z = tonumber(z)
                if z and rec and rec.x and rec.y then
                    zones[#zones + 1] = { z = z, x = rec.x, y = rec.y }
                end
            end
            if #zones >= 2 then
                local parent = {}
                for i = 1, #zones do parent[i] = i end
                local function find(i)
                    while parent[i] ~= i do
                        parent[i] = parent[parent[i]]
                        i = parent[i]
                    end
                    return i
                end
                local function union(a, b)
                    a, b = find(a), find(b)
                    if a ~= b then parent[a] = b end
                end
                for i = 1, #zones do
                    for j = i + 1, #zones do
                        if self:IsLeftoverXyMatch(zones[i].x, zones[i].y, zones[j].x, zones[j].y) then
                            union(i, j)
                        end
                    end
                end
                local clusters = {}
                for i = 1, #zones do
                    local root = find(i)
                    clusters[root] = clusters[root] or {}
                    clusters[root][#clusters[root] + 1] = zones[i]
                end
                for _, group in pairs(clusters) do
                    if #group >= 2 then
                        local keepZ = group[1].z
                        for n = 2, #group do
                            if self:LeftoverKeepBetter(itemID, group[n].z, 0, keepZ, 0) then
                                keepZ = group[n].z
                            end
                        end
                        for n = 1, #group do
                            local z = group[n].z
                            if z ~= keepZ then
                                if allowed[itemID] then
                                    allowed[itemID][z] = nil
                                    allowed[itemID][tostring(z)] = nil
                                    if not next(allowed[itemID]) then
                                        allowed[itemID] = nil
                                    end
                                end
                                byZone[z] = nil
                                byZone[tostring(z)] = nil
                            end
                        end
                    end
                end
            end
        end
    end
end

-- True only when StarterDB lists this item and this zone (not "unrestricted").
function LootCollector:HasStarterDBZoneEntry(itemID, zoneID)
    itemID = tonumber(itemID)
    zoneID = tonumber(zoneID)
    if not itemID or not zoneID or not self.StarterDBItemZones then return false end
    local function zoneOk(id)
        local allowed = self.StarterDBItemZones[id]
        if not allowed then return false end
        return allowed[zoneID] == true or allowed[tostring(zoneID)] == true
    end
    if zoneOk(itemID) then return true end
    local base = self.GetBaseItemID and self:GetBaseItemID(itemID)
    return (base and zoneOk(base)) or false
end

function LootCollector:IsAuthorityPin(d)
    if type(d) ~= "table" then return false end
    if (tonumber(d.mc) or 0) >= 5 then return true end
    if self.GetCoordAuthorityEntry and self:GetCoordAuthorityEntry(d.i, d.z) then return true end
    return self:HasStarterDBZoneEntry(d.i, d.z)
end

function LootCollector:IsVoteFaded(d)
    if type(d) ~= "table" then return false end
    local Constants = self:GetModule("Constants", true)
    local fadeThresh = Constants and Constants.DELETION_THRESHOLD_FADING or 5
    return (tonumber(d.adc) or 0) >= fadeThresh
end

function LootCollector:_ResolveStarterDBBaseByName(name, incomingID)
    if not name or name == "" or not self.StarterDBItemZones or not self.itemInfoCache then
        return nil
    end
    local key = string.lower(name)
    incomingID = tonumber(incomingID)
    for id in pairs(self.StarterDBItemZones) do
        local bid = tonumber(id)
        if bid and bid ~= incomingID then
            local cached = self.itemInfoCache[bid] or self.itemInfoCache[id]
            if cached and cached[1] and string.lower(cached[1]) == key then
                return bid
            end
        end
    end
    return nil
end

function LootCollector:_IndexWfBaseName(index, name, itemID)
    if not name or name == "" or not itemID then return end
    local key = string.lower(name)
    local existing = index[key]
    if existing == nil then
        index[key] = itemID
    elseif existing ~= itemID then
        index[key] = false
    end
end

function LootCollector:_EnsureWfBaseNameIndex()
    if self._wfBaseNameIndex then return self._wfBaseNameIndex end
    local index = {}
    local db = self.WorldforgedUpgrades
    if db then
        for baseID in pairs(db) do
            local bid = tonumber(baseID) or baseID
            local cached = self.itemInfoCache and self.itemInfoCache[bid]
            local name = cached and cached[1]
            if name then
                self:_IndexWfBaseName(index, name, bid)
            end
        end
    end
    local discoveries = self.GetDiscoveriesDB and self:GetDiscoveriesDB()
    if discoveries then
        local Constants = self:GetModule("Constants", true)
        local BM = Constants and Constants.DISCOVERY_TYPE and Constants.DISCOVERY_TYPE.BLACKMARKET
        for _, d in pairs(discoveries) do
            if type(d) == "table" and d.i and not d.vendorType and d.dt ~= BM then
                local di = tonumber(d.i)
                if di and self:_IsKnownWorldforgedBase(di) then
                    local n = ExtractItemNameFromHint(d.il) or (self.itemInfoCache and self.itemInfoCache[di] and self.itemInfoCache[di][1])
                    if n then
                        self:_IndexWfBaseName(index, n, di)
                    end
                end
            end
        end
    end
    if self.StarterDBItemZones and self.itemInfoCache then
        for id in pairs(self.StarterDBItemZones) do
            local bid = tonumber(id) or id
            local cached = self.itemInfoCache[bid] or self.itemInfoCache[id]
            if cached and cached[1] then
                self:_IndexWfBaseName(index, cached[1], bid)
            end
        end
    end
    self._wfBaseNameIndex = index
    return index
end

function LootCollector:_ResolveBaseItemIDByName(name, incomingReqLevel, incomingID)
    if not name or name == "" then return nil end
    local index = self:_EnsureWfBaseNameIndex()
    local baseID = index[string.lower(name)]
    if not baseID or baseID == incomingID then
        baseID = self:_ResolveStarterDBBaseByName(name, incomingID)
        if baseID and index then
            self:_IndexWfBaseName(index, name, baseID)
        end
    end
    if not baseID or baseID == incomingID then return nil end

    if incomingReqLevel then
        local cached = self.itemInfoCache and self.itemInfoCache[baseID]
        local baseReq = cached and cached[5]
        if baseReq == nil then
            baseReq = select(5, GetItemInfo(baseID))
        end
        if baseReq and baseReq >= incomingReqLevel then
            return nil
        end
    end
    return baseID
end

function LootCollector:GetBaseItemID(id, nameHint)
    id = tonumber(id) or 0
    if id == 0 then return 0 end
    if not self.upgradeToBase then
        self.upgradeToBase = {}
        local db = self.WorldforgedUpgrades
        if db then
            for baseID, upgrades in pairs(db) do
                for _, upgradeID in pairs(upgrades) do
                    if upgradeID then
                        self.upgradeToBase[upgradeID] = tonumber(baseID) or baseID
                    end
                end
            end
        end
    end
    local mapped = self.upgradeToBase[id]
    if mapped then return mapped end
    if self:_IsKnownWorldforgedBase(id) then return id end

    local name = ExtractItemNameFromHint(nameHint)
    local reqLevel
    local cached = self.itemInfoCache and self.itemInfoCache[id]
    if cached then
        name = name or cached[1]
        reqLevel = cached[5]
    end
    if not name or reqLevel == nil then
        local n, _, _, _, minLevel = GetItemInfo(id)
        name = name or n
        if reqLevel == nil then reqLevel = minLevel end
    end
    if reqLevel and reqLevel ~= 60 then
        return id
    end
    if not name then return id end

    local baseID = self:_ResolveBaseItemIDByName(name, reqLevel, id)
    if baseID then
        self.upgradeToBase[id] = baseID
        return baseID
    end
    return id
end

-- Phase 0 is the first level-60 upgrade. The bundled table is sparse for
-- items unavailable in an earlier phase, so nil means "not in this phase".
function LootCollector:GetWorldforgedPhaseItemID(id, phase)
    local baseID = self:GetBaseItemID(id)
    phase = tonumber(phase) or 0
    if phase <= 0 then return baseID end

    local upgrades = self.WorldforgedUpgrades and self.WorldforgedUpgrades[baseID]
    return (upgrades and upgrades[phase + 3]) or baseID
end

function LootCollector:IsWorldforgedUpgradeable(id)
    local baseID = self:GetBaseItemID(id)
    if not self.WorldforgedUpgrades or not self.WorldforgedUpgrades[baseID] then
        return false
    end

    -- Memoized: this runs inside map/minimap pin refresh loops, and each
    -- un-memoized call costs a GetItemInfo lookup (a server query when the
    -- item is uncached). The answer is static per item.
    local memo = self._wfUpgradeableMemo
    if not memo then
        memo = {}
        self._wfUpgradeableMemo = memo
    end
    local cached = memo[baseID]
    if cached ~= nil then return cached end

    local name, _, _, _, _, _, _, _, equipSlot, _, _, classID = GetItemInfo(baseID)
    local result = true
    if classID == 1 or equipSlot == "INVTYPE_BAG" then
        result = false
    end
    -- Only memoize once item data is actually available: uncached items
    -- fail open (treated as upgradeable) but must stay re-checkable so
    -- bags get excluded correctly once their data arrives.
    if name then
        memo[baseID] = result
    end
    return result
end

SLASH_LCPROFILER1 = "/lcprofiler"
SlashCmdList["LCPROFILER"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "on" then
        LootCollector._profilerEnabled = true
        print("|cffff7f00LootCollector:|r Profiler |cff00ff00enabled|r.")
    elseif msg == "off" then
        LootCollector._profilerEnabled = false
        print("|cffff7f00LootCollector:|r Profiler |cffff5555disabled|r.")
    elseif msg == "reset" then
        if LootCollector._profilerStats then wipe(LootCollector._profilerStats) end
        print("|cffff7f00LootCollector:|r Profiler stats reset.")
    elseif msg == "report" then
        local stats = LootCollector._profilerStats
        if not stats or not next(stats) then
            print("|cffff7f00LootCollector:|r No profiler data. Use /lcprofiler on first.")
            return
        end
        local rows = {}
        for name, s in pairs(stats) do
            table.insert(rows, { name = name, total = s.total or 0, calls = s.calls or 0, max = s.max or 0 })
        end
        table.sort(rows, function(a, b) return a.total > b.total end)
        print("|cffff7f00LootCollector:|r Top functions by total ms:")
        for i = 1, math.min(15, #rows) do
            local r = rows[i]
            print(string.format("  %2d. %s - total %.1fms, calls %d, max %.2fms", i, r.name, r.total, r.calls, r.max))
        end
    else
        print("|cffff7f00LootCollector:|r /lcprofiler on | off | report | reset")
    end
end

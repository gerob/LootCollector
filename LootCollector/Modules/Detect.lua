local L = LootCollector
local Detect = L:NewModule("Detect", "AceEvent-3.0")

local LEGACY_DETECT_MODE = false 

Detect.recentlyScannedNPCs = Detect.recentlyScannedNPCs or {}
-- NPCs confirmed as ordinary (non-special) merchants. Session-scoped so
-- MERCHANT_UPDATE buy/sell/buyback never re-probes Honor Quartermaster etc.
Detect._nonSpecialNPCs = Detect._nonSpecialNPCs or {}
Detect._cache, Detect._recent = { isWF = {}, isMS = {} }, {}
Detect._dirtyBags = {}
Detect._bagUpdateTimer = nil

Detect._lastDiscoveryGUID = nil
Detect._lastDiscoveryTime = 0

local NPCScanTip = CreateFrame("GameTooltip", "LootCollector_NPCScanTip", UIParent, "GameTooltipTemplate")
NPCScanTip:SetOwner(UIParent, "ANCHOR_NONE")

local lastLootContext = {
    openedAt = 0,
    mapID = 0,
    c = 0, z = 0, iz = 0,
    x = 0, y = 0,
}
Detect._ctx = {
  lastLootOpenedAt = nil,
  lastGossipAt = nil,
  lastMerchantAt = nil,
  lastEmoteAt = nil,
  lastMailTakeAt = nil,
  mailOpen = false,
  lastQuestCompleteAt = nil,
  lastQuestFinishedAt = nil, 
  lastQuestTurnedInAt = nil, 
  lastQuestMsgAt = nil,      
  lastTradeAcceptedAt = nil,
  tradeOpen = false,
  craftingOpen = false,
  
  bankOpen = false,
  guildBankOpen = false,
  lastAchievementAt = nil,
  lastBuybackAt = nil,
}
local LOOT_VALIDITY_WINDOW = 20
local ITEM_EXPECTATION_WINDOW = 9.0
local CHANNEL_STAMP_WINDOW = 15.0

Detect._expectingItemUntil = 0
Detect._expectedItemLink = nil
Detect._lastChannelAt = 0
Detect._channelContext = nil
Detect._pendingBindItemID = nil
Detect._lootWindowOpen = false
Detect._lootCloseGen = 0

function Detect:Debug(msg, ...) return end

local function ParseItemID(link)
  if not link then return nil end
  return tonumber(link:match("item:(%d+)"))
end

local SCAN_TIP_NAME = "LootCollectorDetectScanTip"
local scanTip = nil

local function EnsureScanTip()
    if scanTip then return end
    scanTip = CreateFrame("GameTooltip", SCAN_TIP_NAME, nil, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function TooltipHas(link, needle)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not link or not needle then 
        if pTime then L:ProfileStop("Scanner:TooltipHas", pTime) end
        return false 
    end
    EnsureScanTip()
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    
    
    for i = 2, 5 do
        local fs = _G[SCAN_TIP_NAME .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if text and string.find(string.lower(text), string.lower(needle), 1, true) then
            if pTime then L:ProfileStop("Scanner:TooltipHas", pTime) end
            return true
        end
    end
    
    
    local line1Left = _G[SCAN_TIP_NAME .. "TextLeft1"]
    if line1Left and line1Left:GetText() == "Retrieving item information..." then
        if pTime then L:ProfileStop("Scanner:TooltipHas", pTime) end
        return nil 
    end
    
    if pTime then L:ProfileStop("Scanner:TooltipHas", pTime) end
    return false
end

local function ScanMerchant()
  local items = {}
  local n = GetMerchantNumItems()
  if n == 0 then return items end
  
  for i = 1, n do
    local link = GetMerchantItemLink(i)
    local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i)
    local itemID = ParseItemID(link)

    local costs = {}
    if extendedCost then
      local costKinds = GetMerchantItemCostInfo(i)
      for j = 1, (costKinds or 0) do
        local costTexture, costAmount, costLink, currencyName = GetMerchantItemCostItem(i, j)
        local costItemID = ParseItemID(costLink)
        costs[#costs+1] = {
          amount = costAmount,
          link = costLink,
          itemID = costItemID,
          currencyName = currencyName,
          texture = costTexture,
        }
      end
    end

    if itemID then
        items[#items+1] = {
          index = i,
          itemID = itemID,
          link = link,
          name = name,
          price = price,
          stack = quantity,
          numAvailable = numAvailable,
          isUsable = isUsable,
          extendedCost = extendedCost,
          costs = costs,
        }
    end
  end
  return items
end

local function GetNPCSubname(unit)
  if not unit or not UnitExists(unit) then return nil end
  NPCScanTip:ClearLines()
  NPCScanTip:SetUnit(unit)
  local line2 = _G["LootCollector_NPCScanTipTextLeft2"]
  local text = line2 and line2:IsShown() and line2:GetText() or nil

  if text then
      
      local cleanText = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      if cleanText:match("^Level %d") or tonumber(cleanText:match("(%d+)")) then
          return nil
      end
  end
  return text
end

function Detect:IsWorldforged(link)
    local c = self._cache.isWF[link]
    if c ~= nil then return c end

    -- Curated-list override: a handful of Worldforged world drops (vanity
    -- companions/consumables like Frightened Kitten) carry NO "Worldforged"
    -- line in their tooltip, so the tag scan alone can never detect their
    -- discovery and they stayed "Undiscovered" forever even after looting.
    -- Items whose (base) ID is on the dev-provided WorldforgedList qualify
    -- regardless of tooltip text.
    local itemID = L.ExtractItemID and L:ExtractItemID(link)
    if itemID and L.IsWorldforgedListItem and L:IsWorldforgedListItem(itemID) then
        self._cache.isWF[link] = true
        return true
    end

    local ok = TooltipHas(link, "worldforged")
    
    if ok == nil then
        L._ddebug("Detect", string.format("IsWorldforged scan for %s: Retrieving item data (nil from TooltipHas)", tostring(link)))
        return nil 
    end

    L._ddebug("Detect", string.format("IsWorldforged scan for %s: %s", tostring(link), tostring(ok)))
    self._cache.isWF[link] = ok
    return ok
end

function Detect:IsMysticScroll(link, source)
  local Constants = L:GetModule("Constants", true)
  if Constants and not Constants:HasMysticScrolls() then return false end

  local name = (link and select(1, GetItemInfo(link))) or (link and link:match("%[(.-)%]")) or ""
  if name == "" then return false end
  if L.ignoreList and L.ignoreList[name] then return false end
  if L.sourceSpecificIgnoreList and L.sourceSpecificIgnoreList[name] and source ~= "world_loot" and source ~= "direct" then
    return false
  end
  return string.find(name, "Mystic Scroll:", 1, true) ~= nil
end

function Detect:Qualifies(link, source)
  if not link then return false end
  local isWF = self:IsWorldforged(link)
  local isMS = self:IsMysticScroll(link, source)
  
  
  if isWF == nil then
      L._ddebug("Detect", string.format("Qualifies check for %s | WF: Data Not Ready, MS: %s", tostring(link), tostring(isMS)))
      return nil
  end
  
  L._ddebug("Detect", string.format("Qualifies check for %s | WF: %s, MS: %s", tostring(link), tostring(isWF), tostring(isMS)))
  return isWF or isMS
end

function Detect:OnRetroactiveSuppressionEvent(event, arg1, arg2)
    local shouldSuppress = false
    local reason = "Unknown"

    if event == "UI_INFO_MESSAGE" and arg1 == "|cFF2EF50EItem recovery completed|r" then
        shouldSuppress = true
        reason = "item recovery"
    elseif event == "RECOVERY_RESULT" and arg2 and type(arg2) == "string" and string.find(arg2, "_OK$") then
        shouldSuppress = true
        reason = "item recovery"
    elseif event == "PURCHASE_CUSTOM_STORE_ITEM_RESULT" and arg1 == "PURCHASE_CUSTOM_STORE_ITEM_OK" then
        
        shouldSuppress = true
        reason = "store purchase or upgrade"
    end

    if shouldSuppress then
        L._ddebug("Detect", "Retroactive suppression event detected: " .. event)
        local now = GetTime()
        
        -- Only undo a discovery recorded within the last 2.5s (same clock as stamps above).
        if self._lastDiscoveryGUID and (now - self._lastDiscoveryTime < 2.5) then
            local Core = L:GetModule("Core", true)
            if Core and Core.RemoveDiscoveryByGuid then
                L._ddebug("Detect", "Retroactively removing false discovery due to " .. reason .. ": " .. self._lastDiscoveryGUID)
                Core:RemoveDiscoveryByGuid(self._lastDiscoveryGUID, "Discovery suppressed due to " .. reason .. ".")
            end
        end

        
        self._lastDiscoveryGUID = nil
        self._lastDiscoveryTime = 0
    end
end

-- Special vendor subname rules. Matching is CASE-INSENSITIVE because some
-- vendors present their subname in different capitalization (e.g. the Ring
-- Vendor appears in capitals on some nameplates/tooltips).
-- vendorType values: "BM" = Blackmarket Artisan, "EX" = Exquisite
-- Collectables, "RING" = Ring Vendor. EX/RING reuse the legacy vendor types
-- that the Viewer/Map/repair-pass already know how to label and render.
local SPECIAL_VENDOR_SUBNAMES = {
  { match = "blackmarket artisan supplies", vendorType = "BM" },
  { match = "exquisite collectables",       vendorType = "EX" },
  { match = "ring vendor",                  vendorType = "RING" },
}

local function GetSpecialVendorType(unit)
  local sub = GetNPCSubname(unit)
  if not sub or sub == "" then return nil end
  local lowered = string.lower(sub)
  for _, rule in ipairs(SPECIAL_VENDOR_SUBNAMES) do
    if string.find(lowered, rule.match, 1, true) then
      return rule.vendorType
    end
  end
  return nil
end

local function IsBlackmarketArtisan(unit)
  return GetSpecialVendorType(unit) == "BM"
end

function Detect:OnNPCInteraction()
if L:IsPaused() then return end
    local unitToCheck = "npc"
    if not UnitExists(unitToCheck) then return end

    local npcGUID = UnitGUID(unitToCheck)
    if not npcGUID then return end

    -- Ordinary merchants (Honor Quartermaster, etc.): never ScanMerchant on
    -- buy/sell/buyback. Remembered for the session after first classification.
    if self._nonSpecialNPCs[npcGUID] then
        return
    end

    if self.recentlyScannedNPCs[npcGUID] and (time() - self.recentlyScannedNPCs[npcGUID] < 10) then
        return
    end

    -- Cheap subname check first — do not build a full merchant inventory yet.
    local specialVendorType = GetSpecialVendorType(unitToCheck)
    local isBMVendor = specialVendorType ~= nil
    local isMSVendor = false
    local Constants = L:GetModule("Constants", true)
    local numMerchantItems = (GetMerchantNumItems and GetMerchantNumItems()) or 0

    if not isBMVendor then
        if numMerchantItems == 0 then
            -- Gossip-only / merchant not ready: do not classify as ordinary yet
            -- (an MS vendor may still open after gossip).
            return
        end
        -- Name-only MS probe (no cost/link tables). Honor QM still pays this
        -- once per session, then is remembered as non-special.
        if Constants and Constants:HasMysticScrolls() then
            for i = 1, numMerchantItems do
                local name = GetMerchantItemInfo(i)
                if name and string.find(name, "Mystic Scroll", 1, true) then
                    isMSVendor = true
                    break
                end
            end
        end
        if not isMSVendor then
            self._nonSpecialNPCs[npcGUID] = true
            return
        end
    elseif numMerchantItems == 0 then
        -- Special BM/EX/RING matched on gossip before the shop is open:
        -- do not stamp or push an empty inventory to Core.
        return
    end

    -- Confirmed special / MS vendor: rate-limit full inventory scans.
    self.recentlyScannedNPCs[npcGUID] = time()

    local merchantItems = ScanMerchant()

    local vendorType = isMSVendor and "MS" or specialVendorType
    local now = time()
    
    local cPos, mapID, px, py
    if L.GetPlayerZoneMapPosition then
        cPos, mapID, px, py = L:GetPlayerZoneMapPosition()
    else
        if SetMapToCurrentZone then SetMapToCurrentZone() end
        px, py = GetPlayerMapPosition("player")
        px = px or 0; py = py or 0
        mapID = GetCurrentMapAreaID()
        cPos = GetCurrentMapContinent() or 0
    end

    local ZoneList = L:GetModule("ZoneList", true)
    local zoneInfo = ZoneList and ZoneList.MapDataByID[mapID]

    local c, z, iz
    if zoneInfo then
        c = zoneInfo.continentID
        z = mapID
        iz = 0
    else 
        c = cPos or 0
        z = mapID
        iz = mapID
    end

    local discovery = {
        c = c, z = z, iz = iz, mapID = mapID,
        xy = { x = px, y = py }, 
        t0 = now,
        src = "merchant",
        vendorType = vendorType, 
        vendorName = UnitName(unitToCheck),
        vendorItems = merchantItems, 
        fp = UnitName("player"),
        dt = Constants and Constants.DISCOVERY_TYPE.BLACKMARKET,
    }

    local Core = L:GetModule("Core", true)
    if Core and Core.HandleLocalLoot then
        L._ddebug("Detect", string.format("Passing Vendor %s (%s) to Core.", discovery.vendorName, vendorType))
        Core:HandleLocalLoot(discovery)
    end
end

-- In-game diagnostic for vendor detection. Stand at the vendor, open their
-- shop window, then type /lcvendor. Prints every gate so failures are
-- identifiable without guesswork.
SLASH_LCVENDORCHECK1 = "/lcvendor"
SlashCmdList["LCVENDORCHECK"] = function()
    print("|cffe5cc80LootCollector Vendor Check|r |cff888888(build " .. (L.BuildStamp or "pre-s7") .. ")|r:")
    if L.LEGACY_MODE_ACTIVE then
        print("  |cffff5555Legacy mode active - detection disabled.|r")
        return
    end
    if L.IsPaused and L:IsPaused() then
        print("  |cffff5555Addon is PAUSED - detection is disabled right now.|r")
    end
    local unit = (UnitExists("npc") and "npc") or (UnitExists("target") and "target") or nil
    if not unit then
        print("  No NPC found. OPEN the vendor's shop window (or target them) and try again.")
        return
    end
    local name = UnitName(unit) or "?"
    local sub = GetNPCSubname(unit)
    local vtype = GetSpecialVendorType(unit)
    local merch = (GetMerchantNumItems and GetMerchantNumItems()) or 0
    print(string.format("  NPC: |cffffff00%s|r | subname: |cffffff00%s|r | rule match: %s | merchant items visible: %d",
        name, tostring(sub or "none"), vtype and ("|cff00ff00" .. vtype .. "|r") or "|cffff5555NO MATCH|r", merch))
    if not vtype then
        print("  The subname above did not match any rule. Screenshot this line for the maintainer.")
        return
    end
    if unit ~= "npc" or merch == 0 then
        print("  |cffffff00Note:|r recording requires the SHOP WINDOW to be OPEN (UnitExists(\"npc\") and merchant items > 0).")
        print("  |cffff5555Skipped force-scan.|r Open the shop and run /lcvendor again.")
        return
    end
    if Detect.recentlyScannedNPCs then
        local g = UnitGUID(unit)
        if g then Detect.recentlyScannedNPCs[g] = nil end
    end
    if Detect._nonSpecialNPCs then
        local g = UnitGUID(unit)
        if g then Detect._nonSpecialNPCs[g] = nil end
    end
    local function scanDB()
        local dbV = L.GetVendorsDB and L:GetVendorsDB()
        local n, found = 0, false
        if dbV then
            for _, rec in pairs(dbV) do
                n = n + 1
                if rec and rec.vendorName == name then found = true end
            end
        end
        return n, found
    end
    local before = select(1, scanDB())
    Detect:OnNPCInteraction()
    local after, foundNow = scanDB()
    if after > before then
        print("  |cff00ff00Recorded!|r New vendor entry added to your database.")
    elseif foundNow then
        print("  |cff00ff00This vendor has a database entry|r (name match). If it's missing from the Vendors tab, screenshot this line.")
    else
        print("  |cffff5555Scan ran but this vendor was NOT recorded.|r Screenshot this output for the maintainer.")
    end
end

local function CapturePlayerLootPosition()
    local cPos, mapID, px, py
    if L.GetPlayerZoneMapPosition then
        cPos, mapID, px, py = L:GetPlayerZoneMapPosition()
    else
        if SetMapToCurrentZone then SetMapToCurrentZone() end
        px, py = GetPlayerMapPosition("player")
        mapID = GetCurrentMapAreaID()
        cPos = GetCurrentMapContinent() or 0
    end
    local ZoneList = L:GetModule("ZoneList", true)
    local zoneInfo = ZoneList and ZoneList.MapDataByID[mapID]
    local ctx = {
        x = px or 0,
        y = py or 0,
        mapID = mapID,
    }
    if zoneInfo then
        ctx.c = zoneInfo.continentID
        ctx.z = mapID
        ctx.iz = 0
    else
        ctx.c = cPos or 0
        ctx.z = mapID
        ctx.iz = mapID
    end
    return ctx
end

function Detect:StampChannelPosition()
    self._lastChannelAt = GetTime()
    self._channelContext = CapturePlayerLootPosition()
end

function Detect:OnUnitSpellcastChannelStart(event, unit)
    if unit and unit ~= "player" then return end
    self:StampChannelPosition()
end

function Detect:OnUnitSpellcastStart(event, unit, spell)
    if unit and unit ~= "player" then return end
    local name = string.lower(tostring(spell or ""))
    if name == "" then return end
    if string.find(name, "opening", 1, true)
        or string.find(name, "mining", 1, true)
        or string.find(name, "herb", 1, true)
        or string.find(name, "gather", 1, true)
        or string.find(name, "loot", 1, true) then
        self:StampChannelPosition()
    end
end

function Detect:OnLootBindConfirm(event, slot)
    slot = tonumber(slot)
    if not slot then return end
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local itemID = ParseItemID(link)
    if not itemID then return end
    self._pendingBindItemID = itemID
end

function Detect:ClearPendingBind()
    self._pendingBindItemID = nil
end

function Detect:ClearSpawnPickupStamps()
    self:ClearPendingBind()
    self._lastChannelAt = 0
    self._channelContext = nil
end

function Detect:IsSpawnPickup(link, isWF)
    if not isWF or not link then return false end
    local nowSession = GetTime()
    -- Window still open: original channel counts even past 15s (bags-full reloot).
    -- Window just closed: CHAT_MSG_LOOT may fire the same frame; channel stamp still required.
    local channelOk = self._lootWindowOpen
        or (self._lastChannelAt and self._lastChannelAt > 0
            and (nowSession - self._lastChannelAt) <= CHANNEL_STAMP_WINDOW)
    local lootID = ParseItemID(link)
    local bindID = self._pendingBindItemID
    local sameItem = false
    if lootID and bindID then
        if L.GetBaseItemID then
            sameItem = L:GetBaseItemID(lootID) == L:GetBaseItemID(bindID)
        else
            sameItem = lootID == bindID
        end
    end
    return channelOk and sameItem
end

function Detect:OnLootOpened()
    self._lootWindowOpen = true
    self._lootCloseGen = (self._lootCloseGen or 0) + 1
    self._ctx.lastLootOpenedAt = time()
    lastLootContext.openedAt = time()

    local ctx = CapturePlayerLootPosition()
    local nowSession = GetTime()
    if self._lastChannelAt and self._lastChannelAt > 0
        and (nowSession - self._lastChannelAt) <= CHANNEL_STAMP_WINDOW and self._channelContext then
        ctx = self._channelContext
    end
    lastLootContext.x = ctx.x or 0
    lastLootContext.y = ctx.y or 0
    lastLootContext.mapID = ctx.mapID
    lastLootContext.c = ctx.c
    lastLootContext.z = ctx.z
    lastLootContext.iz = ctx.iz
end

function Detect:OnLootClosed()
    self._lootWindowOpen = false
    self._expectingItemUntil = GetTime() + ITEM_EXPECTATION_WINDOW
    local gen = self._lootCloseGen or 0
    -- CHAT_MSG_LOOT can fire on the same close; clear stamps next frame.
    if L.ScheduleAfter then
        L:ScheduleAfter(0.01, function()
            if Detect._lootWindowOpen then return end
            if (Detect._lootCloseGen or 0) ~= gen then return end
            Detect:ClearSpawnPickupStamps()
        end)
    else
        self:ClearSpawnPickupStamps()
    end
end

function Detect:OnSystemMessage(_, msg)
    if msg and string.find(msg, " completed.") then
        self._ctx.lastQuestMsgAt = time()
    end
end

function Detect:OnInitialize()
  if L.LEGACY_MODE_ACTIVE then return end
  
  self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
  self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
  self:RegisterEvent("LOOT_BIND_CONFIRM", "OnLootBindConfirm")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnUnitSpellcastChannelStart")
  self:RegisterEvent("UNIT_SPELLCAST_START", "OnUnitSpellcastStart")
  
  self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")

  
  self:RegisterEvent("GOSSIP_SHOW", function() self._ctx.lastGossipAt = time(); self:OnNPCInteraction() end)
  self:RegisterEvent("GOSSIP_CLOSED", function() self._ctx.lastGossipAt = time(); self._expectingItemUntil = GetTime() + ITEM_EXPECTATION_WINDOW end)
  self:RegisterEvent("MERCHANT_SHOW", function() self._ctx.lastMerchantAt = time(); self:OnNPCInteraction() end)
  self:RegisterEvent("MERCHANT_UPDATE", function() self._ctx.lastMerchantAt = time(); self:OnNPCInteraction() end)
  self:RegisterEvent("MERCHANT_CLOSED", function() self._ctx.lastMerchantAt = nil end)
  self:RegisterEvent("MAIL_SHOW", function() self._ctx.mailOpen = true end)
  self:RegisterEvent("MAIL_CLOSED", function() self._ctx.mailOpen = false end)
  self:RegisterEvent("AUCTION_HOUSE_SHOW", function() self._ctx.auctionOpen = true end)
  self:RegisterEvent("AUCTION_HOUSE_CLOSED", function() self._ctx.auctionOpen = false end)
  self:RegisterEvent("CHAT_MSG_LOOT", "OnChatMsgLoot")
  
  self:RegisterEvent("QUEST_COMPLETE", function() self._ctx.lastQuestCompleteAt = time() end)
  self:RegisterEvent("QUEST_FINISHED", function() self._ctx.lastQuestFinishedAt = time() end)
  self:RegisterEvent("QUEST_TURNED_IN", function() self._ctx.lastQuestTurnedInAt = time() end)
  self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")

  self:RegisterEvent("TRADE_SHOW", function() self._ctx.tradeOpen = true end)
  self:RegisterEvent("TRADE_CLOSED", function() self._ctx.tradeOpen = false; self._ctx.lastTradeAcceptedAt = nil end)
  self:RegisterEvent("TRADE_ACCEPTED", function() self._ctx.lastTradeAcceptedAt = time() end)
  self:RegisterEvent("TRADE_SKILL_SHOW", function() self._ctx.craftingOpen = true end)
  self:RegisterEvent("TRADE_SKILL_CLOSE", function() self._ctx.craftingOpen = false end)
  self:RegisterEvent("CRAFT_SHOW", function() self._ctx.craftingOpen = true end)
  self:RegisterEvent("CRAFT_CLOSE", function() self._ctx.craftingOpen = false end)
  
  self:RegisterEvent("BANK_FRAME_OPENED", function() self._ctx.bankOpen = true end)
  self:RegisterEvent("BANK_FRAME_CLOSED", function() self._ctx.bankOpen = false end)
  self:RegisterEvent("GUILDBANKFRAME_OPENED", function() self._ctx.guildBankOpen = true end)
  self:RegisterEvent("GUILDBANKFRAME_CLOSED", function() self._ctx.guildBankOpen = false end)
  self:RegisterEvent("ACHIEVEMENT_EARNED", function() self._ctx.lastAchievementAt = time() end)

  self:RegisterEvent("UI_INFO_MESSAGE", "OnRetroactiveSuppressionEvent")
  self:RegisterEvent("RECOVERY_RESULT", "OnRetroactiveSuppressionEvent")
  self:RegisterEvent("PURCHASE_CUSTOM_STORE_ITEM_RESULT", "OnRetroactiveSuppressionEvent")

  if hooksecurefunc then
    hooksecurefunc("TakeInboxItem", function() Detect._ctx.lastMailTakeAt = time() end)
    hooksecurefunc("DoEmote", function() Detect._ctx.lastEmoteAt = time() end)
    hooksecurefunc("BuybackItem", function() Detect._ctx.lastBuybackAt = time() end)
  end
end

local function classifySource(ctx, now)
  local QUEST_WINDOW = 30.0

  if ctx.mailOpen or (ctx.lastMailTakeAt and (now - ctx.lastMailTakeAt <= 3)) then return "mail" end
  if ctx.tradeOpen or (ctx.lastTradeAcceptedAt and (now - ctx.lastTradeAcceptedAt <= 3)) then return "trade" end
  if ctx.auctionOpen then return "auction" end
  if ctx.bankOpen then return "bank" end
  if ctx.guildBankOpen then return "guild_bank" end
  
  if (ctx.lastQuestCompleteAt and (now - ctx.lastQuestCompleteAt <= 5)) or
     (ctx.lastQuestFinishedAt and (now - ctx.lastQuestFinishedAt <= QUEST_WINDOW)) or
     (ctx.lastQuestTurnedInAt and (now - ctx.lastQuestTurnedInAt <= QUEST_WINDOW)) or
     (ctx.lastQuestMsgAt and (now - ctx.lastQuestMsgAt <= QUEST_WINDOW)) then 
     return "quest_reward" 
  end

  if ctx.lastAchievementAt and (now - ctx.lastAchievementAt <= 3) then return "achievement" end
  if ctx.craftingOpen then return "crafting" end
  if _G.C_MysticEnchant and _G.C_MysticEnchant.HasNearbyMysticAltar and _G.C_MysticEnchant.HasNearbyMysticAltar() then return "mystic_altar" end
  if ctx.lastBuybackAt and (now - ctx.lastBuybackAt <= 3) then return "vendor_buyback" end
  if ctx.lastMerchantAt and (now - ctx.lastMerchantAt <= 5) then return "vendor" end
  -- Bags-full: window stays open while the player frees a slot, often >5s.
  if Detect._lootWindowOpen then return "world_loot" end
  if ctx.lastLootOpenedAt and (now - ctx.lastLootOpenedAt <= 5) then return "world_loot" end
  if ctx.lastGossipAt and (now - ctx.lastGossipAt <= 5) then return "npc_gossip" end
  if ctx.lastEmoteAt and (now - ctx.lastEmoteAt <= 5) then return "emote_event" end
  return "direct"
end

function Detect:OnChatMsgLoot(_, msg)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if L:IsPaused() then 
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end

    local Constants = L:GetModule("Constants", true)
    if Constants and Constants.ALLOW_PVP_INSTANCES == false then
        local isInstance, instanceType = IsInInstance()
        if isInstance and (instanceType == "pvp" or instanceType == "arena") then
            L._ddebug("Detect", "Dropped: Loot event occurred inside a PvP instance.")
            if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
            return
        end
    end
    L._ddebug("Detect", "OnChatMsgLoot fired: " .. tostring(msg))
    
    local link = msg and msg:match("|Hitem:%d+:[^|]+|h%[[^%]]+%]|h")
    if not link then 
        L._ddebug("Detect", "Dropped: No item link found in chat message.")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end

    local _, _, playerName = string.find(msg, "([^%s]+)%s+receives loot:")
    local looter = playerName or UnitName("player")
    
    if looter ~= UnitName("player") then 
        L._ddebug("Detect", string.format("Ignored third-party loot event from '%s'. Awaiting their network broadcast to prevent coordinate desync.", tostring(looter)))
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end
    
    local nowTime = time()
    local src = classifySource(self._ctx, nowTime)
    L._ddebug("Detect", "Source originally classified as: " .. tostring(src))

    -- Fast-deny vendor/mail/etc. before tooltip WF scans. quest_reward stays
    -- until after the WF override below (WF world drops can be mis-tagged).
    local earlyDenied = { mail = true, trade = true, crafting = true, mystic_altar = true, vendor = true, vendor_buyback = true, bank = true, guild_bank = true, achievement = true, auction = true }
    if earlyDenied[src] then 
        L._ddebug("Detect", "Dropped: Source is in denied list (" .. tostring(src) .. ")")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end

    local isWF = self:IsWorldforged(link)
    if isWF == false then
        local lootID = ParseItemID(link)
        if lootID and lootID == self._pendingBindItemID then
            self:ClearPendingBind()
        end
    end
    -- Looted flag is independent of pin create/move and of class usability.
    if isWF then
        local lootID = ParseItemID(link)
        if lootID and L.MarkWorldforgedItemLooted then
            L:MarkWorldforgedItemLooted(lootID)
        end
    end
    if isWF and src == "quest_reward" then
        if lastLootContext.openedAt and (nowTime - lastLootContext.openedAt) <= LOOT_VALIDITY_WINDOW then
            src = "world_loot"
            L._ddebug("Detect", "Override: Changed quest_reward to world_loot (WF items do not come from quests)")      
        end
    end

    -- Capital WF upgrades (AP NPC) fire CHAT_MSG_LOOT with src=direct and no
    -- loot window. Bag/ProcessPotentialDiscovery already rejects those; the
    -- chat path must too or they become mc=1 pins at a leftover map AreaID.
    if isWF and src ~= "world_loot" then
        L._ddebug("Detect", "Dropped: Worldforged chat loot is not from a loot window (" .. tostring(src) .. ")")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end
        return
    end

    if src == "quest_reward" then
        L._ddebug("Detect", "Dropped: Source is in denied list (quest_reward)")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end

    if src == "world_loot" and not self._lootWindowOpen
        and (nowTime - lastLootContext.openedAt) > LOOT_VALIDITY_WINDOW then 
        L._ddebug("Detect", "Dropped: world_loot timeframe expired (Window closed).")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end

    local c, z, iz, x_val, y_val
    if src == "world_loot" then
        c, z, iz = lastLootContext.c, lastLootContext.z, lastLootContext.iz
        x_val, y_val = lastLootContext.x, lastLootContext.y
        local nowSession = GetTime()
        if self._lastChannelAt and (nowSession - self._lastChannelAt) <= CHANNEL_STAMP_WINDOW and self._channelContext then
            c = self._channelContext.c
            z = self._channelContext.z
            iz = self._channelContext.iz
            x_val = self._channelContext.x
            y_val = self._channelContext.y
        end
    else
        local cPos, mapID, px, py
        if L.GetPlayerZoneMapPosition then
            cPos, mapID, px, py = L:GetPlayerZoneMapPosition()
        else
            if SetMapToCurrentZone then SetMapToCurrentZone() end
            mapID = GetCurrentMapAreaID()
            cPos = GetCurrentMapContinent() or 0
            px, py = GetPlayerMapPosition("player")
        end
        local ZoneList = L:GetModule("ZoneList", true)
        local zoneInfo = ZoneList and ZoneList.MapDataByID[mapID]

        if zoneInfo then
            c = zoneInfo.continentID 
            z = mapID
            iz = 0
        else
            c = cPos or 0
            z = mapID
            iz = mapID
        end
        
        x_val, y_val = px or 0, py or 0
    end
    
    if Constants and Constants.IsForbiddenZone and Constants:IsForbiddenZone(c, z, looter) then
        L._ddebug("Detect", "Dropped: Looted inside a forbidden zone.")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return
    end

    local qualifies = self:Qualifies(link, src)
    
    if qualifies == nil then
        L._ddebug("Detect", "Data not ready. Queueing cache request and delaying CHAT_MSG_LOOT evaluation by 1 second.")
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
            local Core = L:GetModule("Core", true)
            if Core and Core.QueueItemForCaching then
                Core:QueueItemForCaching(itemID)
                Core:EnsureCachePump()
            end
        end
        L:ScheduleAfter(1.0, function()
            self:OnChatMsgLoot(nil, msg)
        end)
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return
    elseif qualifies == false then
        L._ddebug("Detect", "Dropped: Item does not qualify (Not WF or MS).")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end
    
    local last = self._recent[link] or 0
    local nowSession = GetTime()
    if nowSession - last < 1.0 then 
        L._ddebug("Detect", "Dropped: Throttled (Looted multiple in <1s).")
        if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
        return 
    end
    self._recent[link] = nowSession

    L._ddebug("Detect", "SUCCESS: Passing " .. tostring(link) .. " to Core:HandleLocalLoot.")
    local spawnPickup = self:IsSpawnPickup(link, isWF)
    if spawnPickup then
        self:ClearPendingBind()
    end
    local discovery = { il = link, c = c, z = z, iz = iz, xy = { x = x_val, y = y_val }, t0 = nowTime, src = src, fp = looter, spawnPickup = spawnPickup }
    local Core = L:GetModule("Core", true)
    if Core and Core.HandleLocalLoot then
        local itemID = tonumber(link:match("item:(%d+)"))
        local guid = L:GenerateGUID(c, z, iz, itemID, x_val, y_val)
        self._lastDiscoveryGUID = guid
        -- Session clock: must match GetTime() in OnRetroactiveSuppressionEvent.
        self._lastDiscoveryTime = GetTime()
        Core:HandleLocalLoot(discovery)
    end
    
    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID then
        L:SendMessage("LOOTCOLLECTOR_PLAYER_LOOTED_ITEM", itemID, c, z, x_val, y_val)
    end
    
    if pTime then L:ProfileStop("Detect:OnChatMsgLoot", pTime) end 
end

function Detect:ProcessPotentialDiscovery(link, sourceHint, looterName)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if L:IsPaused() then 
        if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
        return 
    end

    local Constants = L:GetModule("Constants", true)
    if Constants and Constants.ALLOW_PVP_INSTANCES == false then
        local isInstance, instanceType = IsInInstance()
        if isInstance and (instanceType == "pvp" or instanceType == "arena") then
            L._ddebug("Detect", "Dropped: Loot event occurred inside a PvP instance.")
            if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
            return
        end
    end
    
    local nowTime = time()
    looterName = looterName or UnitName("player")
    local src = classifySource(self._ctx, nowTime)
        
    local isWF = self:IsWorldforged(link)
    if isWF and src == "quest_reward" then
        if lastLootContext.openedAt and (nowTime - lastLootContext.openedAt) <= LOOT_VALIDITY_WINDOW then
            src = "world_loot"  
		end			
    end

    local deniedSources = { mail = true, quest_reward = true, trade = true, crafting = true, mystic_altar = true, vendor = true, vendor_buyback = true, bank = true, guild_bank = true, achievement = true, auction = true }
    if deniedSources[src] then 
        if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
        return 
    end

    local isMS = self:IsMysticScroll(link, src)
    if not isWF and not isMS then 
        if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
        return 
    end
    if isWF and src ~= "world_loot" then 
        if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
        return 
    end
    
    local c, z, iz, px, py
    if src == "world_loot" and (nowTime - lastLootContext.openedAt) <= LOOT_VALIDITY_WINDOW then
        c, z, iz, px, py = lastLootContext.c, lastLootContext.z, lastLootContext.iz, lastLootContext.x, lastLootContext.y
    else
        local cPos, mapID, px2, py2
        if L.GetPlayerZoneMapPosition then
            cPos, mapID, px2, py2 = L:GetPlayerZoneMapPosition()
        else
            if SetMapToCurrentZone then SetMapToCurrentZone() end
            mapID = GetCurrentMapAreaID()
            cPos = GetCurrentMapContinent() or 0
            px2, py2 = GetPlayerMapPosition("player")
        end
        local ZoneList = L:GetModule("ZoneList", true)
        local zoneInfo = ZoneList and ZoneList.MapDataByID[mapID]

        if zoneInfo then
            c = zoneInfo.continentID 
            z = mapID
            iz = 0
        else
            c = cPos or 0
            z = mapID
            iz = mapID
        end
        
        px, py = px2 or 0, py2 or 0
    end

    if Constants and Constants.IsForbiddenZone and Constants:IsForbiddenZone(c, z, looterName) then
        if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
        return
    end

    local discovery = { il = link, c = c, z = z, iz = iz, xy = { x = px, y = py }, t0 = nowTime, src = src, fp = looterName }
    local Core = L:GetModule("Core", true)
    if Core and Core.HandleLocalLoot then
        local itemID = tonumber(link:match("item:(%d+)"))
        local guid = L:GenerateGUID(c, z, iz, itemID, px, py)
        self._lastDiscoveryGUID = guid
        -- Session clock: must match GetTime() in OnRetroactiveSuppressionEvent.
        self._lastDiscoveryTime = GetTime()
        Core:HandleLocalLoot(discovery)
    end
    
    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID then
        L:SendMessage("LOOTCOLLECTOR_PLAYER_LOOTED_ITEM", itemID, c, z, px, py)
    end
    
    if pTime then L:ProfileStop("Detect:ProcessPotentialDiscovery", pTime) end 
end

local function ProcessDirtyBags()
    local pTime = L.ProfileStart and L:ProfileStart() 

    Detect._bagUpdateTimer = nil
    if L:IsPaused() then 
        if pTime then L:ProfileStop("Detect:ProcessDirtyBags", pTime) end 
        return 
    end
    
    -- Session clock must match _expectingItemUntil (set via GetTime()).
    -- Keep scanning while the loot window is open (bags-full, then a later take).
    local nowSession = GetTime()
    if nowSession > Detect._expectingItemUntil and not Detect._lootWindowOpen then
        wipe(Detect._dirtyBags)
        if pTime then L:ProfileStop("Detect:ProcessDirtyBags", pTime) end 
        return
    end

    -- Wall clock for classifySource (ctx stamps use time()).
    local now = time()
    local src = classifySource(Detect._ctx, now)
    local deniedSources = { mail = true, quest_reward = true, trade = true, crafting = true, mystic_altar = true, vendor = true, vendor_buyback = true, bank = true, guild_bank = true, achievement = true, auction = true }
    if deniedSources[src] then 
        wipe(Detect._dirtyBags)
        if pTime then L:ProfileStop("Detect:ProcessDirtyBags", pTime) end 
        return 
    end
    
    for link, timestamp in pairs(Detect._recent) do
        if nowSession - timestamp > 3.0 then
            Detect._recent[link] = nil
        end
    end
    
    for bagID in pairs(Detect._dirtyBags) do
        for slotID = 1, GetContainerNumSlots(bagID) do
            local link = GetContainerItemLink(bagID, slotID)
            if link and not Detect._recent[link] then
                local qualifies = Detect:Qualifies(link, "direct")
                
                if qualifies == nil then
                    local itemID = tonumber(link:match("item:(%d+)"))
                    if itemID then
                        local Core = L:GetModule("Core", true)
                        if Core and Core.QueueItemForCaching then
                            Core:QueueItemForCaching(itemID)
                            Core:EnsureCachePump()
                        end
                    end
                else
                    Detect._recent[link] = nowSession
                    if qualifies then
                        local itemID = ParseItemID(link)
                        local skipKnownWF = false
                        if itemID and Detect:IsWorldforged(link) then
                            local Core = L:GetModule("Core", true)
                            local c = lastLootContext.c
                            local z = lastLootContext.z
                            if (not c or not z or c == 0) and L.GetPlayerZoneMapPosition then
                                local cPos, mapID = L:GetPlayerZoneMapPosition()
                                local ZoneList = L:GetModule("ZoneList", true)
                                local zoneInfo = ZoneList and ZoneList.MapDataByID[mapID]
                                c = zoneInfo and zoneInfo.continentID or cPos
                                z = mapID
                            end
                            if Core and Core.GetWorldforgedInZone and Core:GetWorldforgedInZone(c, z, itemID) then
                                skipKnownWF = true
                            end
                        end
                        if skipKnownWF then
                            if L.MarkWorldforgedItemLooted then
                                L:MarkWorldforgedItemLooted(itemID)
                            end
                            L:SendMessage(
                                "LOOTCOLLECTOR_PLAYER_LOOTED_ITEM",
                                itemID,
                                lastLootContext.c,
                                lastLootContext.z,
                                lastLootContext.x,
                                lastLootContext.y
                            )
                        else
                            Detect:ProcessPotentialDiscovery(link, "bag_update", UnitName("player"))
                        end
                    end
                end
            end
        end
    end
    wipe(Detect._dirtyBags)
    
    if pTime then L:ProfileStop("Detect:ProcessDirtyBags", pTime) end 
end

function Detect:OnBagUpdate(event, bagID)
    if not bagID then return end
    self._dirtyBags[bagID] = true
    if not self._bagUpdateTimer then
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            self._bagUpdateTimer = C_Timer.After(0.2, ProcessDirtyBags)
        else
            
            ProcessDirtyBags()
        end
    end
end

return Detect
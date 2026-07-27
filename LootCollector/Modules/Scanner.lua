local L = LootCollector
local Scanner = L:NewModule("Scanner")

local SCANNER_FRAME_NAME = "LootCollector_UnifiedScanner"

local RETRIEVING_TEXT = "Retrieving item information..."

local CLASS_LOCAL_BY_TOKEN, TOKEN_BY_LOCAL = nil, nil
local function BuildClassLocalizationMaps()
    if CLASS_LOCAL_BY_TOKEN then return end
    CLASS_LOCAL_BY_TOKEN, TOKEN_BY_LOCAL = {}, {}
    local Constants = L:GetModule("Constants", true)
    local m = _G.LOCALIZED_CLASS_NAMES_MALE or {}
    local f = _G.LOCALIZED_CLASS_NAMES_FEMALE or {}
    local activeClasses = Constants and Constants:GetActiveClasses() or { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    
    for _, tok in ipairs(activeClasses) do
        local loc = m[tok] or f[tok] or tok
        CLASS_LOCAL_BY_TOKEN[tok] = loc
        TOKEN_BY_LOCAL[string.lower(loc)] = tok
    end
end

local function escape_lua_pattern(s)
    return (s:gsub("(%W)", "%%%1"))
end

function Scanner:OnInitialize()
    if not self.tooltip then
        self.tooltip = CreateFrame("GameTooltip", SCANNER_FRAME_NAME, nil, "GameTooltipTemplate")
        self.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    BuildClassLocalizationMaps()
    
    
    if L.db and L.db.global then
        L.db.global.scannerData = L.db.global.scannerData or {}
        self.dbCache = L.db.global.scannerData
    else
        self.dbCache = {}
    end
    
    
    self.ramCache = {} 
    
    
    C_Timer.After(15, function() self:StartBackgroundHydration() end)
end

function Scanner:ClearCache()
    wipe(self.dbCache)
    wipe(self.ramCache)
end

local function ExtractClassToken(lineText)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not lineText or lineText == "" then 
        if pTime then L:ProfileStop("Scanner:ExtractClassToken", pTime) end
        return nil 
    end
    local lower = string.lower(lineText)

    local list = lower:match("^classes:%s*(.+)$")
    if list then
        for localName, tok in pairs(TOKEN_BY_LOCAL) do
            if string.find(list, localName, 1, true) then 
                if pTime then L:ProfileStop("Scanner:ExtractClassToken", pTime) end
                return tok 
            end
        end
    end

    for localName, tok in pairs(TOKEN_BY_LOCAL) do
        local pat = "%f[%w]" .. escape_lua_pattern(localName) .. "%f[%W]"
        if lower:find(pat) or lower:find(localName, 1, true) then
            if pTime then L:ProfileStop("Scanner:ExtractClassToken", pTime) end
            return tok
        end
    end
    
    if pTime then L:ProfileStop("Scanner:ExtractClassToken", pTime) end
    return nil
end

-- Peek tooltip fullText without SetHyperlink. Used by map Deep Filter so pin
-- rebuilds never hitch on tooltip scans. Returns "" when not yet cached.
function Scanner:GetCachedFullText(itemID, itemLink)
    if not self.ramCache then return "" end
    local cacheKey = itemLink or itemID
    if not cacheKey then return "" end
    local ramData = self.ramCache[cacheKey]
    if ramData and ramData.fullText then
        return ramData.fullText
    end
    -- Also try numeric ID key when a link was passed (and vice versa).
    if itemLink and itemID then
        ramData = self.ramCache[itemID]
        if ramData and ramData.fullText then
            return ramData.fullText
        end
    elseif itemID and not itemLink then
        local link = select(2, GetItemInfo(itemID))
        if link then
            ramData = self.ramCache[link]
            if ramData and ramData.fullText then
                return ramData.fullText
            end
        end
    end
    return ""
end

--[[ Stat detection ---------------------------------------------------------
    Two sources, unioned:

      1. GetItemStats(link) - Blizzard's structured stat table, keyed by
         ITEM_MOD_* constant names. Exact and localisation-proof, so it is the
         primary source. Unknown keys are ignored, so a key name that does not
         exist on this client simply contributes nothing.
      2. The tooltip text - catches what the API does not report: shield block
         value, "chance to block/hit/crit" wordings, and custom Ascension lines.

    Results are persisted per item (statMask), so once any character on the
    account has seen an item its stats are known at load with no rescan and no
    dependency on the client item cache.
--]]
local _strfind, _strsub = string.find, string.sub

local STAT_MATCH_PREFIX = "prefix"
local STAT_MATCH_SUFFIX = "suffix"

local function HasQualifiedStat(text, q)
    local word     = q.word
    local mode     = q.mode
    local wantPre  = (mode ~= STAT_MATCH_SUFFIX)
    local wantPost = (mode ~= STAT_MATCH_PREFIX)
    local init = 1

    while true do
        local s, e = _strfind(text, word, init, true)
        if not s then return false end
        init = e + 1

        local excluded = false
        if q.exclude then
            for i = 1, #q.exclude do
                local ex = q.exclude[i]
                if _strsub(text, e + 1, e + #ex) == ex then
                    excluded = true
                    break
                end
            end
        end

        if not excluded then
            if wantPre and s > 1 then
                local head = _strsub(text, (s > 9) and (s - 9) or 1, s - 1)
                if _strfind(head, "%d%%?%s*$") then return true end
            end
            if wantPost then

                local tail = _strsub(text, e + 1, e + 24)
                if _strfind(tail, "^%s*by%s+[%a%s]*%d") or _strfind(tail, "^%s*:%s*%d") then
                    return true
                end
            end
        end
    end
end

local STAT_FILTERS = {
    { key = "strength",   label = "Strength",
      qualified = { { word = "strength" } } },
    { key = "agility",    label = "Agility",
      qualified = { { word = "agility" } } },
    { key = "stamina",    label = "Stamina",
      qualified = { { word = "stamina" } } },
    { key = "intellect",  label = "Intellect",
      qualified = { { word = "intellect" } } },
    { key = "spirit",     label = "Spirit",
      qualified = { { word = "spirit" } } },

    { key = "attackpower", label = "Attack Power",
      plain = { "attack power" } },
    { key = "spellpower",  label = "Spell Power",
      plain = { "spell power", "spell damage", "damage done by magical spells",
                "damage and healing done by magical spells" } },
    { key = "healing",     label = "Bonus Healing",
      plain = { "healing power", "bonus healing", "healing done by spells",
                "healing done by magical spells", "increases healing" } },
    { key = "mp5",         label = "MP5 (Mana Regen)",
      plain = { "mana per 5 sec", "mana every 5 sec", "mana regen", "mp5" } },
    { key = "hit",         label = "Hit Rating",
      plain = { "hit rating", "chance to hit" } },
    { key = "crit",        label = "Crit Rating",
      plain = { "critical strike rating", "crit rating", "critical strike chance",
                "critical strike by", "chance to crit" },
      qualified = { { word = "critical strike", mode = STAT_MATCH_PREFIX } } },
    { key = "haste",       label = "Haste",
      plain = { "haste rating", "attack speed", "casting speed" },
      qualified = { { word = "haste" } } },
    { key = "expertise",   label = "Expertise",
      plain = { "expertise" } },
    { key = "armorpen",    label = "Armor Penetration",
      plain = { "armor penetration" } },

    { key = "armor",       label = "Armor",
      qualified = { { word = "armor", exclude = { " penetration" } } } },
    { key = "defense",     label = "Defense",
      plain = { "defense" } },
    { key = "dodge",       label = "Dodge",
      plain = { "dodge" } },
    { key = "parry",       label = "Parry",
      plain = { "parry" } },
    { key = "blockrating", label = "Block Rating",
      plain = { "block rating", "chance to block" } },
    { key = "blockvalue",  label = "Block Value",
      plain = { "block value" },
      qualified = { { word = "block", mode = STAT_MATCH_PREFIX,
                      exclude = { " rating", " chance" } } } },
    { key = "resilience",  label = "Resilience",
      plain = { "resilience" } },
}

Scanner.STAT_FILTERS = STAT_FILTERS

-- ITEM_MOD_* key -> our stat key. Listed generously: any name absent on this
-- client is simply never returned by GetItemStats and costs nothing.
local API_STAT_MAP = {
    ITEM_MOD_STRENGTH_SHORT  = "strength",
    ITEM_MOD_AGILITY_SHORT   = "agility",
    ITEM_MOD_STAMINA_SHORT   = "stamina",
    ITEM_MOD_INTELLECT_SHORT = "intellect",
    ITEM_MOD_SPIRIT_SHORT    = "spirit",

    ITEM_MOD_ATTACK_POWER_SHORT        = "attackpower",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "attackpower",

    ITEM_MOD_SPELL_POWER_SHORT        = "spellpower",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT  = "spellpower",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "healing",

    ITEM_MOD_MANA_REGENERATION  = "mp5",
    ITEM_MOD_POWER_REGEN0_SHORT = "mp5",

    ITEM_MOD_HIT_RATING_SHORT        = "hit",
    ITEM_MOD_HIT_MELEE_RATING_SHORT  = "hit",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit",
    ITEM_MOD_HIT_SPELL_RATING_SHORT  = "hit",

    ITEM_MOD_CRIT_RATING_SHORT        = "crit",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT  = "crit",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT  = "crit",

    ITEM_MOD_HASTE_RATING_SHORT        = "haste",
    ITEM_MOD_HASTE_MELEE_RATING_SHORT  = "haste",
    ITEM_MOD_HASTE_RANGED_RATING_SHORT = "haste",
    ITEM_MOD_HASTE_SPELL_RATING_SHORT  = "haste",

    ITEM_MOD_EXPERTISE_RATING_SHORT         = "expertise",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "armorpen",
    ITEM_MOD_RESILIENCE_RATING_SHORT        = "resilience",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT     = "defense",
    ITEM_MOD_DODGE_RATING_SHORT             = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT             = "parry",
    ITEM_MOD_BLOCK_RATING_SHORT             = "blockrating",
    ITEM_MOD_BLOCK_VALUE_SHORT              = "blockvalue",

    RESISTANCE0_NAME     = "armor",
    ITEM_MOD_ARMOR_SHORT = "armor",
}

--[[ Bit order below is PERSISTED in SavedVariables as scannerData[key].statMask.
     Only ever APPEND to this list - reordering or removing an entry silently
     invalidates every mask already saved on disk. It is deliberately separate
     from STAT_FILTERS so the menu display order can be changed freely. --]]
local STAT_BIT_ORDER = {
    "strength", "agility", "stamina", "intellect", "spirit",
    "attackpower", "spellpower", "healing", "mp5", "hit", "crit", "haste",
    "expertise", "armorpen", "armor", "defense", "dodge", "parry",
    "blockrating", "blockvalue", "resilience",
}

local STAT_BIT = {}
for i = 1, #STAT_BIT_ORDER do
    STAT_BIT[STAT_BIT_ORDER[i]] = 2 ^ (i - 1)
end

local function EncodeStatMask(set)
    local mask = 0
    for i = 1, #STAT_BIT_ORDER do
        local key = STAT_BIT_ORDER[i]
        if set[key] then mask = mask + STAT_BIT[key] end
    end
    return mask
end

local function DecodeStatMask(mask)
    local out = {}
    for i = #STAT_BIT_ORDER, 1, -1 do
        local key = STAT_BIT_ORDER[i]
        local bitValue = STAT_BIT[key]
        if mask >= bitValue then
            out[key] = true
            mask = mask - bitValue
        end
    end
    return out
end

local function ItemHasStat(text, def)
    if def.plain then
        for i = 1, #def.plain do
            if _strfind(text, def.plain[i], 1, true) then return true end
        end
    end
    if def.qualified then
        for i = 1, #def.qualified do
            if HasQualifiedStat(text, def.qualified[i]) then return true end
        end
    end
    return false
end

function Scanner:ParseStatsFromText(text)
    if not text or text == "" then return nil end
    local found = {}
    for i = 1, #STAT_FILTERS do
        local def = STAT_FILTERS[i]
        if ItemHasStat(text, def) then found[def.key] = true end
    end
    return found
end

-- Adds anything Blizzard's structured stat table reports into `found`.
function Scanner:AddStatsFromAPI(itemLink, found)
    if not itemLink or type(_G.GetItemStats) ~= "function" then return found end

    local ok, apiStats = pcall(_G.GetItemStats, itemLink)
    if not ok or type(apiStats) ~= "table" then return found end

    for apiKey, value in pairs(apiStats) do
        local statKey = API_STAT_MAP[apiKey]
        if statKey and tonumber(value) and tonumber(value) ~= 0 then
            found[statKey] = true
        end
    end
    return found
end

function Scanner:GetItemData(itemID, itemLink)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not itemID and not itemLink then 
        if pTime then L:ProfileStop("Scanner:GetItemData", pTime) end
        return nil 
    end

    local cacheKey = itemLink or itemID
    local coreData = self.dbCache[cacheKey]
    local ramData = self.ramCache[cacheKey]

    local linkToScan = itemLink or select(2, GetItemInfo(itemID))
    local isMS = linkToScan and string.find(linkToScan, "Mystic Scroll", 1, true)

    
    if coreData and ramData then
        
        if isMS and not coreData.classToken then
            coreData = nil
        else

            if coreData.statMask == nil and ramData.stats then
                coreData.statMask = EncodeStatMask(ramData.stats)
            end
            local res = {
                isWF = coreData.isWF,
                classToken = coreData.classToken,
                isCollected = coreData.isCollected,
                reqLevel = coreData.reqLevel,
                fullText = ramData.fullText
            }
            if pTime then L:ProfileStop("Scanner:GetItemData", pTime) end
            return res
        end
    end

    
    local itemData = { isWF = false, classToken = nil, isCollected = false, reqLevel = nil }
    local scannedStatMask = nil
    local scanResolved = false

    if coreData then
        itemData.isWF = coreData.isWF
        itemData.classToken = coreData.classToken
        itemData.isCollected = coreData.isCollected
        itemData.reqLevel = coreData.reqLevel
    else
        
        if itemID and C_MysticEnchant and C_MysticEnchant.GetEnchantInfoByItem then
            local ok, enchantInfos = pcall(C_MysticEnchant.GetEnchantInfoByItem, itemID)
            if ok and enchantInfos and type(enchantInfos) == "table" and enchantInfos[1] then
                local info = enchantInfos[1]
                itemData.isWF = info.IsWorldforged == true
                itemData.isCollected = info.Known == true
                if info.ClassRequirements and type(info.ClassRequirements) == "table" and info.ClassRequirements[1] then
                    local cType = info.ClassRequirements[1].ClassType
                    if cType then itemData.classToken = cType:gsub("^Reborn", ""):upper() end
                end
            end
        end

        if not itemData.isCollected and itemID and C_MysticEnchant and C_MysticEnchant.IsCollected then
            local ok, result = pcall(C_MysticEnchant.IsCollected, itemID)
            if ok and result then itemData.isCollected = true end
        end
    end

    if not linkToScan then
        if pTime then L:ProfileStop("Scanner:GetItemData", pTime) end
        return nil
    end

    -- Vendor pseudo-records use negative synthetic item IDs (e.g. -300123
    -- "[Blackmarket Supplies]"); SetHyperlink rejects those with an
    -- "Unknown link type" error. Never scan them, and never let a bad link
    -- hard-error the scanner.
    local scanID = tonumber(itemID) or tonumber(linkToScan:match("item:(%-?%d+)"))
    if scanID and scanID <= 0 then
        if pTime then L:ProfileStop("Scanner:GetItemData", pTime) end
        return itemData
    end

    self.tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    self.tooltip:ClearLines()
    local hlOK = pcall(self.tooltip.SetHyperlink, self.tooltip, linkToScan)
    if not hlOK then
        if pTime then L:ProfileStop("Scanner:GetItemData", pTime) end
        return itemData
    end

    local numLines = self.tooltip:NumLines()
    if numLines > 0 then
        local line1Left = _G[SCANNER_FRAME_NAME .. "TextLeft1"]
        if not (line1Left and line1Left:GetText() == RETRIEVING_TEXT) then
            local textParts = {}
            local reqLevelPattern = _G.ITEM_MIN_LEVEL and _G.ITEM_MIN_LEVEL:gsub("%%d", "(%%d+)") or "Requires Level%s+(%%d+)"
            
            for i = 1, numLines do
                local leftLine = _G[SCANNER_FRAME_NAME .. "TextLeft" .. i]
                local rightLine = _G[SCANNER_FRAME_NAME .. "TextRight" .. i]
                
                local lText = leftLine and leftLine:GetText() or ""
                local rText = rightLine and rightLine:GetText() or ""
                
                if lText ~= "" then table.insert(textParts, lText) end
                if rText ~= "" then table.insert(textParts, rText) end
                
                if not coreData then
                    if not itemData.isWF and (string.find(lText, "Worldforged", 1, true) or string.find(rText, "Worldforged", 1, true)) then
                        itemData.isWF = true
                    end
                    
                    if not itemData.classToken then
                        if string.find(string.lower(lText), "classes:", 1, true) then
                            itemData.classToken = ExtractClassToken(lText)
                        elseif isMS and i <= 4 then
                            
                            
                            local stripped = lText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
                            local tok = TOKEN_BY_LOCAL[string.lower(stripped)]
                            if tok then itemData.classToken = tok end
                        end
                    end
                    
                    if not itemData.reqLevel then
                        local reqLvlText = lText:match(reqLevelPattern) or rText:match(reqLevelPattern)
                        if reqLvlText then itemData.reqLevel = tonumber(reqLvlText) end
                    end
                    if not itemData.isCollected then
                        local stripped = lText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                        if stripped == "Collected" then itemData.isCollected = true end
                    end
                end
            end
            local fullText = string.lower(table.concat(textParts, " "))


            local stats = self:ParseStatsFromText(fullText) or {}
            self:AddStatsFromAPI(linkToScan, stats)
            self.ramCache[cacheKey] = { fullText = fullText, stats = stats }
            scannedStatMask = EncodeStatMask(stats)


            scanResolved = true
        end
    end

    if not coreData then
        self.dbCache[cacheKey] = {
            isWF = itemData.isWF,
            classToken = itemData.classToken,
            isCollected = itemData.isCollected,
            reqLevel = itemData.reqLevel,
            statMask = scannedStatMask,
            scanOK = scanResolved
        }
    else
        if scannedStatMask and coreData.statMask == nil then

            coreData.statMask = scannedStatMask
        end
        if scanResolved and not coreData.scanOK then
            coreData.scanOK = true
            coreData.reqLevel = itemData.reqLevel
        end
    end

    local finalData = {
        isWF = itemData.isWF,
        classToken = itemData.classToken,
        isCollected = itemData.isCollected,
        reqLevel = itemData.reqLevel,
        fullText = self.ramCache[cacheKey] and self.ramCache[cacheKey].fullText or ""
    }

    if pTime then L:ProfileStop("Scanner:GetItemData", pTime) end 
    return finalData
end

-- Returns nil only for items that have never been scanned successfully, so
-- callers retry as the client fills them in. knownText lets a caller that
-- already holds the tooltip text skip a rescan.
function Scanner:GetItemStats(itemID, itemLink, knownText)
    local cacheKey = itemLink or itemID
    if not cacheKey then return nil end

    local ram = self.ramCache and self.ramCache[cacheKey]
    if ram and ram.stats then return ram.stats end

    local core = self.dbCache and self.dbCache[cacheKey]
    if core and core.statMask then
        local found = DecodeStatMask(core.statMask)
        if ram then ram.stats = found end
        return found
    end

    local text = knownText
    if not text or text == "" then text = ram and ram.fullText end
    if not text or text == "" then
        local data = self:GetItemData(itemID, itemLink)
        text = data and data.fullText
        ram  = self.ramCache and self.ramCache[cacheKey]
        core = self.dbCache and self.dbCache[cacheKey]
    end

    local found = self:ParseStatsFromText(text)
    if found then
        self:AddStatsFromAPI(itemLink, found)
        if ram then
            ram.stats = found
        elseif self.ramCache then
            self.ramCache[cacheKey] = { fullText = text, stats = found }
        end
        if core then core.statMask = EncodeStatMask(found) end
    end
    return found
end

function Scanner:MatchesStatFilter(itemID, itemLink, selected, matchAll, knownText)
    if not selected or not next(selected) then return true end

    local stats = self:GetItemStats(itemID, itemLink, knownText)
    if not stats then return false end

    if matchAll then
        for key in next, selected do
            if not stats[key] then return false end
        end
        return true
    end

    for key in next, selected do
        if stats[key] then return true end
    end
    return false
end

-- Required level from the persisted scan, so it works without the client item
-- cache. scanOK marks entries whose tooltip actually resolved - without it a
-- nil reqLevel is ambiguous ("no requirement" vs "never scanned properly").
function Scanner:GetItemReqLevel(itemID, itemLink)
    local cacheKey = itemLink or itemID
    if not cacheKey then return nil end

    local core = self.dbCache and self.dbCache[cacheKey]
    if core and core.scanOK then return core.reqLevel or 0 end

    self:GetItemData(itemID, itemLink)

    core = self.dbCache and self.dbCache[cacheKey]
    if core and core.scanOK then return core.reqLevel or 0 end
    return nil
end

function Scanner:PreWarmCache(itemID, itemLink)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not itemID or not itemLink then 
        if pTime then L:ProfileStop("Scanner:PreWarmCache", pTime) end
        return 
    end
    local key = itemLink or itemID
    if self.dbCache[key] and self.ramCache[key] then 
        if pTime then L:ProfileStop("Scanner:PreWarmCache", pTime) end
        return 
    end   
    self:GetItemData(itemID, itemLink)
    
    if pTime then L:ProfileStop("Scanner:PreWarmCache", pTime) end
end

function Scanner:StartBackgroundHydration()
    local pTime = L.ProfileStart and L:ProfileStart() 

    if self._hydrationInProgress then 
        if pTime then L:ProfileStop("Scanner:StartBackgroundHydration", pTime) end
        return 
    end
    self._hydrationInProgress = true
    self._hydrationQueue = {}
    
    local db = L:GetDiscoveriesDB() or {}
    local seen = {}
    for _, d in pairs(db) do
        local key = d.il or d.i
        if key and not seen[key] and not self.ramCache[key] then
            table.insert(self._hydrationQueue, key)
            seen[key] = true
        end
    end
    
    self:ProcessHydrationChunk()
    
    if pTime then L:ProfileStop("Scanner:StartBackgroundHydration", pTime) end
end

function Scanner:ProcessHydrationChunk()
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not self._hydrationInProgress then 
        if pTime then L:ProfileStop("Scanner:ProcessHydrationChunk", pTime) end
        return 
    end
    if L:IsPaused() or InCombatLockdown() then
        C_Timer.After(2.0, function() self:ProcessHydrationChunk() end)
        if pTime then L:ProfileStop("Scanner:ProcessHydrationChunk", pTime) end
        return
    end
    
    if #self._hydrationQueue == 0 then
        self._hydrationInProgress = false
        L._debug("Scanner", "Background Hydration complete. Deep Search RAM cache is fully loaded.")
        if pTime then L:ProfileStop("Scanner:ProcessHydrationChunk", pTime) end
        return
    end
    
    local BUDGET_MS = 1.0 
    local startMs = debugprofilestop()
    local processed = 0
    
    while #self._hydrationQueue > 0 do
        local key = table.remove(self._hydrationQueue, 1)
        local itemID = type(key) == "number" and key or tonumber(key:match("item:(%d+)"))
        
        if itemID and GetItemInfo(itemID) then
            self:GetItemData(itemID, type(key) == "string" and key or nil)
        end
        
        processed = processed + 1
        if debugprofilestop() - startMs >= BUDGET_MS then break end
    end
    
    C_Timer.After(0.1, function() self:ProcessHydrationChunk() end)
    
    if pTime then L:ProfileStop("Scanner:ProcessHydrationChunk", pTime) end
end

return Scanner
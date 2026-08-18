local L = LootCollector
local Viewer = L:NewModule("Viewer")

Viewer._cacheBuildQueue = {}
Viewer._cacheBuildIndex = 1

function ViewerSetSelectedRow(row)
    if Viewer and Viewer.SetSelectedRow then
        Viewer:SetSelectedRow(row)
    end
end

-- GetItemInfo Armor subtypes offered in the Type filter (Shields is ist=5).
local TYPE_FILTER_ARMOR = { "Cloth", "Leather", "Mail", "Plate", "Shields" }
local TYPE_FILTER_WEAPON = {
    "One-Handed Axes", "Two-Handed Axes", "Bows", "Guns",
    "One-Handed Maces", "Two-Handed Maces", "Polearms",
    "One-Handed Swords", "Two-Handed Swords", "Staves",
    "Fist Weapons", "Daggers", "Thrown", "Crossbows", "Wands", "Fishing Poles",
}
-- GetItemInfo subtype for Neck / Finger / Trinket / Shirt / Tabard (and similar).
local TYPE_FILTER_MISC = { "Miscellaneous" }
local TypeFilterMenuHost = CreateFrame("Frame", "LootCollectorViewerTypeFilterMenuHost", UIParent, "UIDropDownMenuTemplate")
local StatsFilterMenuHost = CreateFrame("Frame", "LootCollectorViewerStatsFilterMenuHost", UIParent, "UIDropDownMenuTemplate")

-- Deep-search chip catalog for Stats EasyMenu (tooltip substring / OR aliases).
local STAT_FILTER_CATEGORIES = {
    {
        name = "Primary",
        stats = {
            { label = "Strength", expr = "strength" },
            { label = "Agility", expr = "agility" },
            { label = "Intellect", expr = "intellect" },
            { label = "Spirit", expr = "spirit" },
            { label = "Stamina", expr = "stamina" },
        },
    },
    {
        name = "Melee",
        stats = {
            { label = "Attack Power", expr = "attack power" },
            { label = "Hit Rating", expr = "hit rating" },
            { label = "Critical Strike", expr = "critical strike" },
            { label = "Haste", expr = "haste" },
            { label = "Expertise", expr = "expertise" },
            { label = "Armor Penetration", expr = "armor penetration" },
        },
    },
    {
        name = "Spell",
        stats = {
            { label = "Spell Power", expr = "spell power" },
            { label = "Hit Rating", expr = "hit rating" },
            { label = "Critical Strike", expr = "critical strike" },
            { label = "Haste", expr = "haste" },
            { label = "MP5 / Mana Regen", expr = "mana every or mp5 or mana regen" },
            { label = "Spell Penetration", expr = "spell penetration" },
        },
    },
    {
        name = "Defense",
        stats = {
            { label = "Defense Rating", expr = "defense rating" },
            { label = "Dodge", expr = "dodge" },
            { label = "Parry", expr = "parry" },
            { label = "Block", expr = "block" },
            { label = "Resilience", expr = "resilience" },
        },
    },
    {
        name = "Misc",
        stats = {
            { label = "PvP Power", expr = "pvp power" },
        },
    },
}

local SOURCE_NAMES = {
    ["world_loot"] = "World Drop",
    ["mail"] = "Mail",
    ["npc_gossip"] = "NPC Gossip",
    ["emote_event"] = "Emote Event",
    ["direct"] = "Direct",
    ["quest"] = "Quest",
    ["trade"] = "Trade",
    ["crafting"] = "Crafting",
    ["unknown"] = "Unknown"
}

local QUALITY_NAMES = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Artifact",
    [7] = "Heirloom"
}

local CLASS_ABBREVIATIONS_REVERSE = {
  ["wa"] = "WARRIOR", ["pa"] = "PALADIN", ["hu"] = "HUNTER", ["ro"] = "ROGUE",
  ["pr"] = "PRIEST", ["dk"] = "DEATHKNIGHT", ["sh"] = "SHAMAN", ["ma"] = "MAGE",
  ["lo"] = "WARLOCK", ["dr"] = "DRUID",
}

local CLASS_OPTIONS = {
  "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","DRUID",
}

local CUSTOM_CLASS_COLORS = {
    ["KNIGHTOFXOROTH"] = {r = 0.77, g = 0.12, b = 0.23},
    ["SONOFARUGAL"]    = {r = 0.77, g = 0.12, b = 0.23},
    ["FLESHWARDEN"]    = {r = 0.77, g = 0.12, b = 0.23},
    ["DEMONHUNTER"]    = {r = 0.64, g = 0.19, b = 0.79},
    ["BARBARIAN"]      = {r = 0.78, g = 0.61, b = 0.43},
    ["CHRONOMANCER"]   = {r = 1.00, g = 0.96, b = 0.41},
    ["CULTIST"]        = {r = 0.53, g = 0.53, b = 0.93},
    ["NECROMANCER"]    = {r = 0.67, g = 0.83, b = 0.45},
    ["PRIMALIST"]      = {r = 1.00, g = 0.49, b = 0.04},
    ["PYROMANCER"]     = {r = 1.00, g = 0.49, b = 0.04},
    ["RANGER"]         = {r = 0.67, g = 0.83, b = 0.45},
    ["REAPER"]         = {r = 0.00, g = 1.00, b = 0.59},
    ["RUNEMASTER"]     = {r = 0.41, g = 0.80, b = 0.94},
    ["STARCALLER"]     = {r = 0.41, g = 0.80, b = 0.94},
    ["STORMBRINGER"]   = {r = 0.00, g = 0.44, b = 0.87},
    ["SUNCLERIC"]      = {r = 1.00, g = 0.49, b = 0.04},
    ["TEMPLAR"]        = {r = 0.96, g = 0.55, b = 0.73},
    ["TINKER"]         = {r = 1.00, g = 0.96, b = 0.41},
    ["VENOMANCER"]     = {r = 0.67, g = 0.83, b = 0.45},
    ["WILDWALKER"]      = {r = 1.00, g = 0.49, b = 0.04},
    ["WITCHDOCTOR"]    = {r = 0.96, g = 0.55, b = 0.73},
    ["WITCHHUNTER"]    = {r = 0.53, g = 0.53, b = 0.93},
    ["GUARDIAN"]       = {r = 0.50, g = 0.50, b = 0.50},
}

Viewer.lootedFilterState = nil 
Viewer.collectedMEFilterState = nil 
Viewer.hasUncachedData = false
Viewer.lastSeenSortState = "off"
-- nil = show all, "hide" = hide FADING/STALE, "only" = only FADING/STALE
Viewer.fadeFilterState = nil

local function DiscoveryIsFadingOrStale(discovery)
    local s = discovery and discovery.s
    return s == "FADING" or s == "STALE"
end

local function PassesFadeFilter(discovery)
    local state = Viewer.fadeFilterState
    if not state then return true end
    local fading = DiscoveryIsFadingOrStale(discovery)
    if state == "hide" then return not fading end
    if state == "only" then return fading end
    return true
end

-- Dev troubleshooting: pending-update ring buffer (session-only; off by default)
Viewer._pendingTraceEnabled = false
Viewer._pendingTrace = {}
Viewer._pendingTraceMax = 32

local time = time or os.time

local WINDOW_WIDTH = 1150
local WINDOW_HEIGHT = 674
local HEADER_HEIGHT = 25
local BUTTON_HEIGHT = 22
local BUTTON_WIDTH = 100
local CONTEXT_MENU_WIDTH = 200
local FRAME_LEVEL = 50
local FRAME_STRATA = "HIGH"

local GRID_LAYOUT = {
    
    NAME_WIDTH = 320,
    FAV_WIDTH = 10,
    LEVEL_WIDTH = 26,
    SLOT_WIDTH = 130,
    TYPE_WIDTH = 150,
    CLASS_WIDTH = 70,
    ZONE_WIDTH = 150,
    FOUND_BY_WIDTH = 120,

    VENDOR_NAME_WIDTH_INLINE = 256,
    VENDOR_NAME_WIDTH_SPLIT = 432, 
    VENDOR_PRICE_WIDTH = 60,
    VENDOR_TYPE_WIDTH = 250,
    VENDOR_INVENTORY_WIDTH = 68,
    VENDOR_ZONE_WIDTH = 150,
    VENDOR_CONTINENT_WIDTH = 128,

    
    COLUMN_SPACING = 8,
}

local ROW_HEIGHT = 24
local ROW_FONT_NAME = "LootCollectorViewerRowFont"
local ROW_FONT_SIZE = 14
local ROW_FONT_PATH = "Fonts\\ARIALN.TTF"

local UI_FONT_NAME = "LootCollectorViewerUIFont"
local UI_FONT_SIZE = 13
local UI_FONT_PATH = "Fonts\\ARIALN.TTF"

Viewer.window         = nil
Viewer.scrollFrame    = nil
Viewer.rows           = {}
Viewer._reusableCurrentFiltered = {}
Viewer._reusableFinalFiltered = {}
Viewer.selectedRow    = nil
Viewer.currentFilter  = "eq" 
Viewer.minReqLevel    = nil
Viewer.maxReqLevel    = nil
Viewer.searchTerm     = ""
Viewer.sortColumn     = "name"      
Viewer.sortAscending  = true
Viewer.pendingMapAreaID = nil

local WORLDFORGED_PHASES = {
    [0] = "Base Item",
    [1] = "Phase 0: Pre-Raid",
    [2] = "Phase 1: Zul'Gurub",
    [3] = "Phase 2: Molten Core",
    [4] = "Phase 3: Blackwing Lair",
    [5] = "Phase 4: Ahn'Qiraj",
    [6] = "Phase 5: Naxxramas",
}

Viewer.currentPage    = 1
Viewer.itemsPerPage   = 500
Viewer.totalItems     = 0

Viewer.columnFilters  = {
    eq       = { slot = {}, type = {}, class = {} },
    ms       = { class = {} },
    zone     = {},
    source   = {},
    quality  = {},
    looted   = {},
    vendorType = {},
    duplicates = false,
}

Viewer.vendorInventoryFrame = nil      
Viewer.vendorInventoryLines = nil      
Viewer.selectedVendorGuid   = nil      

local function VDebug(msg)
    if LootCollector.db and LootCollector.db.profile and LootCollector.db.profile.vdebugMode then
        print("|cffffff00[LC-Viewer]|r " .. tostring(msg))
    end
end

local _next = next
local _getmt, _setmt = getmetatable, setmetatable
local _rawlen = rawlen or function(x) return #x end
local _tinsert = table.insert
local _tremove = table.remove
local _tsort = table.sort
local _tconcat = table.concat
local _strlower = string.lower
local _strfind = string.find
local _strmatch = string.match
local _strgsub = string.gsub

local activeTimers = {} 

local tooltipScanner = CreateFrame("GameTooltip", "LCSearchTooltipScanner", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")

local function GetItemTooltipText(itemLink)
    if not itemLink or itemLink == "" then return nil end
    tooltipScanner:ClearLines()
    tooltipScanner:SetHyperlink(itemLink)
    local fullText = ""
    for i = 1, tooltipScanner:NumLines() do
        local left = _G["LCSearchTooltipScannerTextLeft"..i]
        if left and left:GetText() then
            fullText = fullText .. " " .. left:GetText()
        end
        local right = _G["LCSearchTooltipScannerTextRight"..i]
        if right and right:GetText() then
            fullText = fullText .. " " .. right:GetText()
        end
    end
    if fullText == "" then return nil end
    return string.lower(fullText)
end

-- ============================================================================
-- Deep Search filter expression engine.
-- Each filter row is a typed expression of keywords joined by AND / OR, e.g.
-- "intellect and spellpower" or "haste or spell crit". Rows are combined with
-- AND (each added row narrows the results further). Keywords are matched as
-- case-insensitive substrings of name, zone, tooltip, Type (itemSubType), and
-- Slot (localized equipLoc).
--
-- CompileDeepExpression turns a string into { tokens = {...}, ops = {...} }
-- where ops[i] is the operator ("and"/"or") that joins tokens[i] and tokens[i+1].
-- Splitting on the space-delimited operators preserves multi-word keywords
-- ("spell power") and never splits inside a word ("command").
-- ============================================================================
local function CompileDeepExpression(expr)
    if not expr then return nil end
    local rest = strtrim(string.lower(expr))
    if rest == "" then return nil end
    local tokens, ops = {}, {}
    while true do
        local aStart = string.find(rest, " and ", 1, true)
        local oStart = string.find(rest, " or ", 1, true)
        local opStart, opLen, opName
        if aStart and (not oStart or aStart < oStart) then
            opStart, opLen, opName = aStart, 5, "and"
        elseif oStart then
            opStart, opLen, opName = oStart, 4, "or"
        end
        if not opStart then
            local tok = strtrim(rest)
            if tok ~= "" then tokens[#tokens + 1] = tok end
            break
        end
        local tok = strtrim(string.sub(rest, 1, opStart - 1))
        if tok ~= "" then
            tokens[#tokens + 1] = tok
            ops[#tokens] = opName  -- operator following this token
        end
        rest = string.sub(rest, opStart + opLen)
    end
    if #tokens == 0 then return nil end
    return { tokens = tokens, ops = ops }
end

-- Evaluate one compiled row against a (lowercased) tooltip text, left-to-right,
-- left-associative (AND/OR share precedence). Single-operator rows therefore
-- behave as plain "all keywords" (AND) or "any keyword" (OR).
local function EvalDeepRow(row, text)
    local tokens = row.tokens
    local n = #tokens
    if n == 0 then return true end
    local result = string.find(text, tokens[1], 1, true) ~= nil
    for i = 2, n do
        local op = row.ops[i - 1] or "and"
        local hit = string.find(text, tokens[i], 1, true) ~= nil
        if op == "or" then
            result = result or hit
        else
            result = result and hit
        end
    end
    return result
end

-- Recompile Viewer.deepSearchFilters (list of expression strings) into
-- Viewer.deepSearchCompiled. Called whenever the filter list changes.
function Viewer:RebuildDeepCompiled()
    local out = {}
    local filters = self.deepSearchFilters
    if filters then
        for i = 1, #filters do
            local c = CompileDeepExpression(filters[i])
            if c then out[#out + 1] = c end
        end
    end
    self.deepSearchCompiled = out
end

-- True if any Deep Filter expression is currently set.
function Viewer:HasDeepFilters()
    return self.deepSearchCompiled ~= nil and #self.deepSearchCompiled > 0
end

-- Public matcher: every Deep Filter expression must match the given haystack
-- (lowercased name + zone + tooltip text, space-joined).
function Viewer:MatchesDeepFilter(haystack)
    local compiled = self.deepSearchCompiled
    if not compiled or #compiled == 0 then return true end
    if not haystack or haystack == "" then return false end
    for i = 1, #compiled do
        if not EvalDeepRow(compiled[i], haystack) then return false end
    end
    return true
end

function Viewer:BuildDeepFilterHaystack(name, zone, tooltip, itemSubType, slot)
    return string.lower(
        tostring(name or "") .. " " ..
        tostring(zone or "") .. " " ..
        tostring(tooltip or "") .. " " ..
        tostring(itemSubType or "") .. " " ..
        tostring(slot or "")
    )
end

function Viewer:IsFilterMapEnabled()
    return L.db and L.db.char and L.db.char.mapFilters and L.db.char.mapFilters.applyViewerFiltersOnMap and true or false
end

function Viewer:SetFilterMapEnabled(enabled)
    if not (L.db and L.db.char) then return end
    L.db.char.mapFilters = L.db.char.mapFilters or {}
    L.db.char.mapFilters.applyViewerFiltersOnMap = enabled and true or false
    self:NotifyMapViewerFiltersChanged(true)
    if self.UpdateFilterMapButton then self:UpdateFilterMapButton() end
end

local function copy(t)
    local out = {}
    for k, v in _next, t do out[k] = v end
    local mt = _getmt(t)
    if mt then _setmt(out, mt) end
    return out
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in _next, t do
        if type(v) == "table" then
            out[k] = deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local MAX_FILTER_PRESETS = 10
local PresetsFilterMenuHost = CreateFrame("Frame", "LootCollectorViewerPresetsFilterMenuHost", UIParent, "UIDropDownMenuTemplate")

local function createTimer(delay, callback)
    local timer = C_Timer.After(delay, callback)
    _tinsert(activeTimers, timer)
    return timer
end

local function clearAllTimers()
    for i = #activeTimers, 1, -1 do
        _tremove(activeTimers, i)
    end
end

local function concatStrings(...)
    local args = { ... }
    local result = {}
    local count = 0
    for i = 1, #args do
        if args[i] then
            count = count + 1
            result[count] = tostring(args[i])
        end
    end
    return _tconcat(result)
end

local function size(t)
    if not t then return 0 end
    if t[1] ~= nil then
        return _rawlen(t)
    end
    local n = 0
    for _ in _next, t do n = n + 1 end
    return n
end

local function keys(t)
    local out = {}
    local i = 0
    for k in _next, t do
        i = i + 1
        out[i] = k
    end
    return out
end

local function values(t)
    local out = {}
    local i = 0
    for _, v in _next, t do
        i = i + 1
        out[i] = v
    end
    return out
end

local function filter(array, predicate)
    local n = _rawlen(array)
    local wi = 1
    for i = 1, n do
        local v = array[i]
        if predicate(v, i) then
            if wi ~= i then array[wi] = v end
            wi = wi + 1
        end
    end
    for i = wi, n do array[i] = nil end
    return array
end

local function GetQualityColor(quality)
    quality = tonumber(quality)
    if not quality then return 1, 1, 1 end
    
    local useWCAG = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.useWCAGColoring
    if useWCAG == nil then useWCAG = true end

    if useWCAG then
        
        local WCAG_RGB = {
            [0] = { r = 0.63, g = 0.61, b = 0.58 }, 
            [1] = { r = 1.00, g = 1.00, b = 1.00 }, 
            [2] = { r = 0.12, g = 1.00, b = 0.00 }, 
            [3] = { r = 0.33, g = 0.70, b = 1.00 }, 
            [4] = { r = 0.78, g = 0.52, b = 1.00 }, 
            [5] = { r = 1.00, g = 0.50, b = 0.00 }, 
            [6] = { r = 0.80, g = 0.68, b = 0.47 }, 
            [7] = { r = 0.90, g = 0.80, b = 0.50 }, 
        }
        local c = WCAG_RGB[quality]
        if c then return c.r, c.g, c.b end
    else
        
        if _G.GetItemQualityColor then
            local r, g, b = _G.GetItemQualityColor(quality)
            if r and g and b then return r, g, b end
        end
        if _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality] then
            local c = _G.ITEM_QUALITY_COLORS[quality]
            return c.r or 1, c.g or 1, c.b or 1
        end
    end
    return 1, 1, 1
end

local Cache = {
    discoveries = {},
    discoveriesByGuid = {},
    discoveriesBuilt = false,
    discoveriesBuilding = false,
    itemInfo = {},
    characterClass = {},
    worldforged = {},
    zoneNames = {},
    uniqueValues = {
        slot = {},
        type = {},
        class = {},
        zone = {}
    },
    uniqueValuesValid = false,
    filteredResults = {},
    lastFilterState = nil,
    duplicateItems = {},
    _cleanupRequired = false,
}

L.itemInfoCache = L.itemInfoCache or {}

local function CachedItemInfoRow(d)
    local itemID = d and tonumber(d.i)
    if not itemID then return nil end
    return Cache.itemInfo[itemID] or (L.itemInfoCache and L.itemInfoCache[itemID]) or nil
end

local function GetItemTypeIDs(itemType, itemSubType)
    local Constants = L:GetModule("Constants", true)
    if not Constants then return 0, 0 end
    
    local it = Constants.ITEM_TYPE_TO_ID[itemType] or 0
    local ist = Constants.ITEM_SUBTYPE_TO_ID[itemSubType] or 0
    return it, ist
end

-- Match Viewer type filter selections (English subtype names) against row data.
-- Prefer localized itemSubType from GetItemInfo; fall back to persisted ist /
-- subtype-ID round-trip so "Miscellaneous" matches Finger/Neck/Trinket, etc.
local function DiscoveryMatchesTypeFilter(data, typeFilters)
    if not typeFilters or size(typeFilters) == 0 then return true end
    local Constants = L:GetModule("Constants", true)
    local typeValue = (data and data.itemSubType) or ""
    if typeValue ~= "" and typeFilters[typeValue] then return true end
    if Constants then
        if typeValue ~= "" and Constants.ITEM_SUBTYPE_TO_ID and Constants.ID_TO_ITEM_SUBTYPE then
            local id = Constants.ITEM_SUBTYPE_TO_ID[typeValue]
            local englishName = id and Constants.ID_TO_ITEM_SUBTYPE[id]
            if englishName and typeFilters[englishName] then return true end
        end
        local ist = data and data.ist
        if ist and Constants.ID_TO_ITEM_SUBTYPE then
            local englishName = Constants.ID_TO_ITEM_SUBTYPE[ist]
            if englishName and typeFilters[englishName] then return true end
        end
    end
    return false
end

local function GetItemInfoSafe(itemLink, itemID)
    local queryTarget = itemLink or itemID
    if not queryTarget then return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil end

    if itemID and Cache.itemInfo[itemID] then
        return unpack(Cache.itemInfo[itemID])
    end

    local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, texture, sellPrice =
        GetItemInfo(queryTarget)

    if itemID and name then
        Cache.itemInfo[itemID] = { name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc,
            texture, sellPrice }
        
        L.itemInfoCache[itemID] = Cache.itemInfo[itemID]
    end

    return name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLoc, texture, sellPrice
end

local function GetLocalizedZoneName(discovery)
    if not discovery then
        return "Unknown Zone"
    end

    local c = tonumber(discovery.c) or 0
    local z = tonumber(discovery.z) or 0
    local iz = tonumber(discovery.iz) or 0

    local cacheKey = string.format("%d:%d:%d", c, z, iz)
    if Cache.zoneNames[cacheKey] then
        return Cache.zoneNames[cacheKey]
    end

    local ZoneList = L:GetModule("ZoneList", true)
    local localizedZoneName = "Unknown Zone"

    if ZoneList and ZoneList.GetZoneName then
        localizedZoneName = ZoneList:GetZoneName(c, z, iz) or "Unknown Zone"
    end

    Cache.zoneNames[cacheKey] = localizedZoneName
    return localizedZoneName
end

local function PendingTraceRecord(action, guid, discoveryData)
    if not Viewer._pendingTraceEnabled then return end
    local buf = Viewer._pendingTrace
    if not buf then
        Viewer._pendingTrace = {}
        buf = Viewer._pendingTrace
    end

    local entry = { action = tostring(action or "?") }
    if action == "bulk" and (not guid or guid == "") then
        entry.detail = "(no detail)"
    else
        if guid and guid ~= "" then
            local g = tostring(guid)
            if #g > 36 then g = string.sub(g, 1, 33) .. "..." end
            entry.guid = g
        end
        if discoveryData and type(discoveryData) == "table" then
            if discoveryData.il and discoveryData.il ~= "" then
                entry.item = discoveryData.il
            elseif discoveryData.i then
                local name = GetItemInfo(discoveryData.i)
                entry.item = name or ("item:" .. tostring(discoveryData.i))
            elseif discoveryData.vendorName then
                entry.item = discoveryData.vendorName
            end
            if discoveryData.fp and discoveryData.fp ~= "" then
                entry.fp = tostring(discoveryData.fp)
            end
            local zoneName = GetLocalizedZoneName(discoveryData)
            if zoneName and zoneName ~= "" and zoneName ~= "Unknown Zone" then
                entry.zone = zoneName
            elseif discoveryData.z then
                entry.zone = "z=" .. tostring(discoveryData.z)
            end
        end
    end

    buf[#buf + 1] = entry
    local maxN = Viewer._pendingTraceMax or 32
    while #buf > maxN do
        _tremove(buf, 1)
    end
end

function Viewer:DumpPendingTrace(clearAfter)
    local buf = self._pendingTrace or {}
    local n = #buf
    if n == 0 then
        print("|cff88aaff[LC-Pending]|r (empty)" ..
            (self._pendingTraceEnabled and " — recording on" or " — recording off"))
        return
    end
    print(string.format("|cff88aaff[LC-Pending]|r %d event(s)%s:",
        n, self._pendingTraceEnabled and " (recording on)" or ""))
    for i = 1, n do
        local e = buf[i]
        local parts = { tostring(i) .. ".", e.action or "?" }
        if e.detail then
            parts[#parts + 1] = e.detail
        else
            if e.item then parts[#parts + 1] = e.item end
            if e.zone then parts[#parts + 1] = e.zone end
            if e.fp then parts[#parts + 1] = "fp=" .. e.fp end
            if e.guid then parts[#parts + 1] = "guid=" .. e.guid end
        end
        print(_tconcat(parts, " | "))
    end
    if clearAfter then
        wipe(self._pendingTrace)
    end
end

-- Viewer list row: name / zone / tooltip / Type / Slot (vendors use vendor name).
function Viewer:MatchesDeepFilterOnRow(data)
    if not data then return false end
    local name = data.isVendor and (data.vendorName or "") or (data.itemName or "")
    local zone = data.zoneNameStr or (data.discovery and GetLocalizedZoneName(data.discovery)) or ""
    local tip = data.tooltipText or ""
    local itemSubType = data.itemSubType or ""
    local slot = data.equipLoc and _G[data.equipLoc] or ""
    return self:MatchesDeepFilter(self:BuildDeepFilterHaystack(name, zone, tip, itemSubType, slot))
end

-- Map/Arrow discovery record: name + zone + cached tooltip + Type + Slot (no SetHyperlink).
function Viewer:MatchesDeepFilterOnDiscoveryRecord(d)
    if not d then return false end
    local Constants = L:GetModule("Constants", true)
    local isVendor = (Constants and d.dt == Constants.DISCOVERY_TYPE.BLACKMARKET) or d.vendorType
    local name = ""
    local tip = ""
    local itemSubType = ""
    local slot = ""
    if isVendor then
        name = d.n or d.vendorName or d.name or ""
    else
        local cached = CachedItemInfoRow(d)
        local itemName = cached and cached[1]
        local subType = cached and cached[7]
        local equipLoc = d.el or (cached and cached[9])
        if not itemName then
            itemName, _, _, _, _, _, subType, _, equipLoc = GetItemInfo(d.il or d.i or 0)
        end
        name = itemName or ""
        itemSubType = subType or ""
        if itemSubType == "" and Constants and d.ist and Constants.ID_TO_ITEM_SUBTYPE then
            itemSubType = Constants.ID_TO_ITEM_SUBTYPE[d.ist] or ""
        end
        if not equipLoc or equipLoc == "" then
            equipLoc = d.el
        end
        if (not equipLoc or equipLoc == "") and Constants and d.ist and Constants.IST_TO_EQUIPLOC then
            equipLoc = Constants.IST_TO_EQUIPLOC[d.ist]
        end
        slot = equipLoc and _G[equipLoc] or ""
        local Scanner = L:GetModule("Scanner", true)
        tip = Scanner and Scanner.GetCachedFullText and Scanner:GetCachedFullText(d.i, d.il) or ""
    end
    local zone = GetLocalizedZoneName(d) or ""
    local haystack = self:BuildDeepFilterHaystack(name, zone, tip, itemSubType, slot)
    if self:MatchesDeepFilter(haystack) then return true end
    -- Tooltip chips (Stats) cannot match until Scanner RAM cache fills.
    -- Keep WF pins visible rather than emptying the map; they re-filter later.
    if not isVendor and self:HasDeepFilters() and (not tip or tip == "") then
        self._filterMapUncachedCount = (self._filterMapUncachedCount or 0) + 1
        return true
    end
    return false
end

function Viewer:ResetFilterMapUncachedCount()
    self._filterMapUncachedCount = 0
end

function Viewer:EnsureDeepFiltersLoaded()
    if L.db and L.db.profile then
        if type(L.db.profile.deepSearchFilters) ~= "table" then
            L.db.profile.deepSearchFilters = {}
        end
        self.deepSearchFilters = L.db.profile.deepSearchFilters
    else
        self.deepSearchFilters = self.deepSearchFilters or {}
    end
    if not self.deepSearchCompiled then
        self:RebuildDeepCompiled()
    end
end

-- Viewer filters that should gate map pins when Filter Map is ON.
-- Date sort is Viewer-only and excluded. Fade All/Hide/Only is included.
function Viewer:HasViewerFiltersForMap()
    self:EnsureDeepFiltersLoaded()
    if self.deepSearchFilters and #self.deepSearchFilters > 0 then return true end
    if self.minReqLevel or self.maxReqLevel then return true end
    if size(self.columnFilters.zone) > 0 then return true end
    if self.columnFilters.eq and (size(self.columnFilters.eq.slot) > 0 or size(self.columnFilters.eq.type) > 0 or size(self.columnFilters.eq.class) > 0) then
        return true
    end
    if self.columnFilters.ms and size(self.columnFilters.ms.class) > 0 then return true end
    if size(self.columnFilters.source) > 0 then return true end
    if size(self.columnFilters.quality) > 0 then return true end
    if size(self.columnFilters.vendorType) > 0 then return true end
    if self.lootedFilterState ~= nil or size(self.columnFilters.looted) > 0 then return true end
    if self.collectedMEFilterState ~= nil then return true end
    if self.columnFilters.duplicates then return true end
    if self.favoritesFilterState == true then return true end
    if self.fadeFilterState then return true end
    return false
end

-- Evaluate Discoveries Viewer filter state against a raw discovery record (map/Arrow path).
-- Does not allocate Viewer rows. Equipment-only filters skip MS/vendor pins.
function Viewer:DiscoveryPassesViewerFilters(d)
    if not d then return false end
    self:EnsureDeepFiltersLoaded()
    if not self:HasViewerFiltersForMap() then return true end

    local Constants = L:GetModule("Constants", true)
    local isVendor = (Constants and d.dt == Constants.DISCOVERY_TYPE.BLACKMARKET) or d.vendorType
    local isMystic = Constants and d.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL
    local isWF = not isVendor and not isMystic

    if self:HasDeepFilters() then
        if not self:MatchesDeepFilterOnDiscoveryRecord(d) then
            return false
        end
    end

    if size(self.columnFilters.zone) > 0 then
        local zoneValue = GetLocalizedZoneName(d)
        if not self.columnFilters.zone[zoneValue] then return false end
    end

    if not isVendor then
        if size(self.columnFilters.source) > 0 then
            local source = d.src or "unknown"
            local sourceValue = SOURCE_NAMES[source] or source
            if not self.columnFilters.source[sourceValue] then return false end
        end

        if size(self.columnFilters.quality) > 0 then
            local cached = CachedItemInfoRow(d)
            local quality = d.q or (cached and cached[3])
            if not quality then
                local _, _, q = GetItemInfo(d.il or d.i or 0)
                quality = q
            end
            if not quality then
                if not self.columnFilters.quality["Unknown"] then return false end
            else
                local qualityValue = QUALITY_NAMES[quality] or ("Quality " .. tostring(quality))
                if not self.columnFilters.quality[qualityValue] then return false end
            end
        end

        if size(self.columnFilters.looted) > 0 then
            local lootedValue = (d.g and L:IsLootedByChar(d.g)) and "Looted" or "Not Looted"
            if not self.columnFilters.looted[lootedValue] then return false end
        end

        if self.lootedFilterState ~= nil then
            local isLooted = d.g and L:IsLootedByChar(d.g)
            if self.lootedFilterState == true and not isLooted then return false end
            if self.lootedFilterState == false and isLooted then return false end
        end

        if self.favoritesFilterState == true then
            if not (d.i and L.db and L:GetFavoritesDB()[d.i]) then
                return false
            end
        end

        if self.collectedMEFilterState ~= nil then
            if isMystic and d.i and d.i > 0 then
                local isCollectedME = L:IsMysticEnchantCollected(d.i)
                if self.collectedMEFilterState == true and not isCollectedME then return false end
                if self.collectedMEFilterState == false and isCollectedME then return false end
            elseif self.collectedMEFilterState == true then
                return false
            end
        end

        if self.columnFilters.duplicates then
            if Cache.duplicateItems and d.i then
                if not Cache.duplicateItems[d.i] or Cache.duplicateItems[d.i] <= 1 then
                    return false
                end
            end
        end
    end

    if isWF then
        if self.minReqLevel or self.maxReqLevel then
            local cached = CachedItemInfoRow(d)
            local minLevel = (cached and cached[5]) or 0
            if minLevel == 0 then
                local _, _, _, _, ml = GetItemInfo(d.il or d.i or 0)
                minLevel = ml or 0
            end
            if self.minReqLevel and minLevel < self.minReqLevel then return false end
            if self.maxReqLevel and minLevel > self.maxReqLevel then return false end
        end

        if size(self.columnFilters.eq.slot) > 0 then
            local cached = CachedItemInfoRow(d)
            local equipLoc = d.el or (cached and cached[9])
            if (not equipLoc or equipLoc == "") and Constants then
                if (not equipLoc or equipLoc == "") and d.ist and Constants.IST_TO_EQUIPLOC then
                    equipLoc = Constants.IST_TO_EQUIPLOC[d.ist]
                end
                if (not equipLoc or equipLoc == "") then
                    local _, _, _, _, _, _, _, _, el = GetItemInfo(d.il or d.i or 0)
                    equipLoc = el
                end
            end
            local slotValue = equipLoc and _G[equipLoc] or ""
            if not self.columnFilters.eq.slot[slotValue] then return false end
        end

        if size(self.columnFilters.eq.type) > 0 then
            local cached = CachedItemInfoRow(d)
            local itemSubType = (cached and cached[7]) or ""
            if itemSubType == "" and Constants and d.ist and Constants.ID_TO_ITEM_SUBTYPE then
                itemSubType = Constants.ID_TO_ITEM_SUBTYPE[d.ist] or ""
            end
            if itemSubType == "" then
                local _, _, _, _, _, _, st = GetItemInfo(d.il or d.i or 0)
                itemSubType = st or ""
            end
            if not DiscoveryMatchesTypeFilter({ itemSubType = itemSubType or "", ist = d.ist }, self.columnFilters.eq.type) then
                return false
            end
        end

        if size(self.columnFilters.eq.class) > 0 and Constants and Constants.CLASS_PROFICIENCIES then
            local subTypeID = d.ist
            local typeID = d.it
            -- Resolve type IDs from cached/item info when discovery lacks them.
            if not (subTypeID and typeID and subTypeID > 0 and typeID > 0) then
                local cached = CachedItemInfoRow(d)
                local itemType = cached and cached[6]
                local itemSubType = cached and cached[7]
                if not itemType then
                    local _, _, _, _, _, it, ist = GetItemInfo(d.il or d.i or 0)
                    itemType, itemSubType = it, ist
                end
                if itemType and itemSubType and Constants.ITEM_TYPE_TO_ID and Constants.ITEM_SUBTYPE_TO_ID then
                    typeID = Constants.ITEM_TYPE_TO_ID[itemType] or 0
                    subTypeID = Constants.ITEM_SUBTYPE_TO_ID[itemSubType] or 0
                end
            end
            if not (subTypeID and typeID and subTypeID > 0 and typeID > 0) then
                -- Unknown item type: keep pin (same as non-proficiency gear on Viewer list).
                -- Do not blanket-hide when type data is missing.
            else
                local isProficiencyArmor = Constants.PROFICIENCY_ARMOR_ISTS and Constants.PROFICIENCY_ARMOR_ISTS[subTypeID]
                local isWeapon = (typeID == Constants.ITEM_TYPE_TO_ID["Weapon"])
                if isProficiencyArmor or isWeapon then
                    local canUse = false
                    for classFilterName, _ in pairs(self.columnFilters.eq.class) do
                        local classToken = nil
                        if Constants.GetClassTokenFromLocalizedName then
                            local foundToken = Constants:GetClassTokenFromLocalizedName(classFilterName)
                            if foundToken ~= classFilterName then classToken = foundToken end
                        end
                        if not classToken and _G.LOCALIZED_CLASS_NAMES_MALE then
                            for token, locName in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
                                if locName == classFilterName then classToken = token; break end
                            end
                        end
                        if not classToken then classToken = string.upper(classFilterName) end
                        local profs = Constants.CLASS_PROFICIENCIES[classToken]
                        if profs then
                            local list = nil
                            if typeID == Constants.ITEM_TYPE_TO_ID["Armor"] then list = profs.armor
                            elseif typeID == Constants.ITEM_TYPE_TO_ID["Weapon"] then list = profs.weapons end
                            if list then
                                for _, allowedID in ipairs(list) do
                                    if subTypeID == allowedID then canUse = true; break end
                                end
                            else
                                canUse = true
                            end
                        end
                        if canUse then break end
                    end
                    if not canUse then return false end
                end
            end
        end
    end

    if isMystic and size(self.columnFilters.ms.class) > 0 then
        local classValue = ""
        if d.cl and d.cl ~= "cl" then
            local classToken = CLASS_ABBREVIATIONS_REVERSE[d.cl]
            if classToken then
                classValue = _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[classToken] or classToken
            end
        end
        if classValue == "" or not self.columnFilters.ms.class[classValue] then
            return false
        end
    end

    if isVendor and size(self.columnFilters.vendorType) > 0 then
        local typeMap = { ["BM"] = "Blackmarket", ["MS"] = "Mystic Enchants" }
        local vType = d.vendorType
        if not vType and d.g then
            if string.find(d.g, "BM-", 1, true) then vType = "BM"
            elseif string.find(d.g, "MS-", 1, true) then vType = "MS" end
        end
        local typeName = typeMap[vType] or vType or "Unknown"
        if not self.columnFilters.vendorType[typeName] then return false end
    end

    if not isVendor and not PassesFadeFilter(d) then
        return false
    end

    return true
end

function Viewer:ClearDiscoveriesFilters()
    self.columnFilters.zone = {}
    self.columnFilters.eq.slot = {}
    self.columnFilters.eq.type = {}
    self.columnFilters.eq.class = {}
    self.columnFilters.ms.class = {}
    self.columnFilters.source = {}
    self.columnFilters.quality = {}
    self.columnFilters.looted = {}
    self.columnFilters.vendorType = {}
    self.columnFilters.duplicates = false

    self.lootedFilterState = nil
    self.collectedMEFilterState = nil
    self.favoritesFilterState = nil
    self.hasUncachedData = false
    self.lastSeenSortState = "off"
    self.fadeFilterState = nil

    self.searchTerm = ""
    if self.searchBox then self.searchBox:SetText("") end

    if self.deepSearchFilters then wipe(self.deepSearchFilters) end
    if self.RebuildDeepCompiled then self:RebuildDeepCompiled() end
    if self.RefreshDeepFilterPanel then self:RefreshDeepFilterPanel() end
    if self.deepFilterPanel then self.deepFilterPanel:Hide() end

    self.minReqLevel = nil
    self.maxReqLevel = nil
    if self.minReqLevelBox then self.minReqLevelBox:SetText("") end
    if self.maxReqLevelBox then self.maxReqLevelBox:SetText("") end

    self.currentPage = 1
    Cache.filteredResults = {}
    Cache.lastFilterState = nil
    Cache.uniqueValuesValid = false
    Cache.uniqueValuesContext = {}

    if self.window and self.window:IsShown() then
        if self.UpdateSortHeaders then self:UpdateSortHeaders() end
        if self.RefreshData then self:RefreshData() end
        if self.UpdateClearAllButton then self:UpdateClearAllButton() end
        if self.UpdateFilterButtonStates then self:UpdateFilterButtonStates() end
    end

    self:NotifyMapViewerFiltersChanged(true)
    self:PersistLiveFilters()
end

-- Starter DB CTA helpers (empty Discoveries list).
function Viewer:IsDiscoveryStoreEmpty()
    local discoveries = L.GetDiscoveriesDB and L:GetDiscoveriesDB() or nil
    return not discoveries or not next(discoveries)
end

function Viewer:GetStarterDBAvailability()
    local name, _, _, enabled, loadable, reason = GetAddOnInfo("LootCollector_StarterDB")
    if reason == "MISSING" or not name or name == "" then
        return "missing"
    end
    if reason == "DISABLED" or enabled == false then
        return "disabled"
    end
    -- Some clients put "enabled" in arg4 and "loadable" in arg5; treat either false as disabled.
    if loadable == false and enabled ~= true then
        return "disabled"
    end
    return "available"
end

function Viewer:PromptMergeStarterDatabase()
    local loaded, reason = LoadAddOn("LootCollector_StarterDB")
    if _G.LootCollector_OptionalDB_Data and _G.LootCollector_OptionalDB_Data.data then
        StaticPopup_Show("LOOTCOLLECTOR_MERGE_STARTER_CONFIRM")
        return
    end
    local status = self:GetStarterDBAvailability()
    if status == "disabled" or reason == "DISABLED" then
        print("|cffff7f00LootCollector:|r LootCollector_StarterDB is disabled. Enable it in AddOns at character select, then /reload.")
    elseif status == "missing" or reason == "MISSING" then
        print("|cffff7f00LootCollector:|r LootCollector_StarterDB is not installed. Install it alongside LootCollector, enable it, then /reload.")
    else
        print(string.format("|cffff7f00LootCollector:|r Starter database could not be loaded. Reason: %s", tostring(reason or "unknown")))
    end
end

function Viewer:NotifyDatabaseChanged()
    Cache.discoveriesBuilt = false
    Cache.discoveriesBuilding = false
    Cache.lastDiscoveryCount = nil
    Cache.filteredResults = {}
    Cache.lastFilterState = nil
    Cache.uniqueValuesValid = false
    if self.window and self.window:IsShown() and self.RefreshData then
        self:RefreshData()
    end
end

function Viewer:EnsureEmptyState()
    if self.emptyStateFrame or not self.window or not self.scrollFrame then return end

    local frame = CreateFrame("Frame", nil, self.window)
    frame:SetAllPoints(self.scrollFrame)
    frame:SetFrameStrata(FRAME_STRATA)
    frame:SetFrameLevel(FRAME_LEVEL + 6)
    frame:Hide()
    frame:EnableMouse(false)

    local title = frame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    title:SetPoint("CENTER", frame, "CENTER", 0, 36)
    title:SetWidth(420)
    title:SetJustifyH("CENTER")
    title:SetTextColor(1, 0.82, 0, 1)
    frame.title = title

    local body = frame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    body:SetPoint("TOP", title, "BOTTOM", 0, -10)
    body:SetWidth(440)
    body:SetJustifyH("CENTER")
    body:SetTextColor(0.85, 0.85, 0.90, 1)
    frame.body = body

    local actionBtn = CreateFrame("Button", nil, frame)
    actionBtn:SetSize(200, 26)
    actionBtn:SetPoint("TOP", body, "BOTTOM", 0, -16)
    actionBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    actionBtn:SetBackdropColor(0.12, 0.18, 0.28, 0.95)
    actionBtn:SetBackdropBorderColor(0.35, 0.55, 0.85, 0.95)
    local bfs = actionBtn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    bfs:SetPoint("CENTER", 0, 1)
    bfs:SetTextColor(1, 1, 1, 1)
    actionBtn:SetFontString(bfs)
    actionBtn:SetText("Merge Starter Database")
    actionBtn:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
    end)
    actionBtn:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.35, 0.55, 0.85, 0.95)
    end)
    frame.actionBtn = actionBtn

    self.emptyStateFrame = frame
end

function Viewer:UpdateEmptyState(numFilteredRows)
    self:EnsureEmptyState()
    local frame = self.emptyStateFrame
    if not frame then return end

    if Cache.discoveriesBuilding or (numFilteredRows and numFilteredRows > 0) then
        frame:Hide()
        return
    end

    local storeEmpty = self:IsDiscoveryStoreEmpty()
    if storeEmpty then
        local status = self:GetStarterDBAvailability()
        frame.title:SetText("No discoveries yet")
        if status == "available" then
            frame.body:SetText("Your discovery database is empty. Merge the Starter Database to load starter discoveries (same action as Import/Export).")
            frame.actionBtn:SetText("Merge Starter Database")
            frame.actionBtn:SetScript("OnClick", function()
                Viewer:PromptMergeStarterDatabase()
            end)
            frame.actionBtn:Show()
        elseif status == "disabled" then
            frame.body:SetText("LootCollector_StarterDB is disabled. Enable it in AddOns at character select, then /reload, and open Discoveries again.")
            frame.actionBtn:Hide()
        else
            frame.body:SetText("LootCollector_StarterDB is not installed. Install it alongside LootCollector, enable it at character select, then /reload.")
            frame.actionBtn:Hide()
        end
        frame:Show()
        return
    end

    -- Discoveries exist, but filters/search hid everything.
    frame.title:SetText("Nothing matches your filters")
    frame.body:SetText("Discoveries are present, but current filters or search hid them. Use Clear (top right), or adjust Filter Map if the world map looks empty too.")
    frame.actionBtn:SetText("Clear Filters")
    frame.actionBtn:SetScript("OnClick", function()
        Viewer:ClearDiscoveriesFilters()
    end)
    frame.actionBtn:Show()
    frame:Show()
end

-- Refresh map/minimap when Viewer filters change and Filter Map is ON.
-- force=true rebuilds even when toggling the flag (ON or OFF).
function Viewer:InvalidateArrowFilterCache()
    local Arrow = L:GetModule("Arrow", true)
    if Arrow then
        Arrow._scanKey = nil
        Arrow._fmZoneSet = nil
        Arrow._fmZoneKey = nil
    end
end

function Viewer:NotifyMapViewerFiltersChanged(force)
    if not force and not self:IsFilterMapEnabled() then return end
    self:InvalidateArrowFilterCache()
    local Map = L:GetModule("Map", true)
    if Map then
        Map.cacheIsDirty = true
        if Map.Update then Map:Update() end
        if Map.UpdateMinimap then Map:UpdateMinimap() end
    end
    if self.SchedulePersistLiveFilters then self:SchedulePersistLiveFilters() end
end

function Viewer:ScheduleMapViewerFilterNotify()
    if not self:IsFilterMapEnabled() then return end
    if self._mapFilterNotifyTimer then return end
    self._mapFilterNotifyTimer = C_Timer.After(0.15, function()
        Viewer._mapFilterNotifyTimer = nil
        Viewer:NotifyMapViewerFiltersChanged()
    end)
end

-- Back-compat alias (Deep Filter used to have its own map toggle).
function Viewer:NotifyMapDeepFilterChanged()
    self:ScheduleMapViewerFilterNotify()
end

local localClassScanTip = CreateFrame("GameTooltip", "LootCollectorClassScanTooltip", UIParent, "GameTooltipTemplate")
localClassScanTip:SetOwner(UIParent, "ANCHOR_NONE")

local VALID_CLASSES = {
    ["Warrior"] = true, ["Paladin"] = true, ["Hunter"] = true,
    ["Rogue"] = true, ["Priest"] = true, ["Shaman"] = true,
    ["Mage"] = true, ["Warlock"] = true, ["Druid"] = true
}

local function GetItemCharacterClass(itemLink, itemID)
    if not itemLink or not itemID then return "" end

    local cached = Cache.characterClass[itemID]
    if cached ~= nil then
        return cached
    end

    local characterClass = ""
    localClassScanTip:SetHyperlink(itemLink)
    
    local line2Text = _G["LootCollectorClassScanTooltipTextLeft2"]:GetText()
    if line2Text then
        local plainText = line2Text:match("^|c%x%x%x%x%x%x%x%x(.+)|r$") or line2Text
        local className = plainText:match("^%s*(.-)%s*$")
        if VALID_CLASSES[className] then
            characterClass = line2Text
        end
    end

    Cache.characterClass[itemID] = characterClass
    return characterClass
end

local localWorldforgedScanTip = CreateFrame("GameTooltip", "LootCollectorViewerScanTip", UIParent, "GameTooltipTemplate")
localWorldforgedScanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function IsWorldforged(itemLink)
    if not itemLink then return false end

    local cached = Cache.worldforged[itemLink]
    if cached ~= nil then
        return cached
    end

    local Core = L:GetModule("Core", true)
    local tooltip, tooltipName
    
    if Core and Core._scanTip then
        tooltip = Core._scanTip
        tooltipName = "LootCollectorCoreScanTipTextLeft"
    else
        if not localWorldforgedScanTip then
            localWorldforgedScanTip = CreateFrame("GameTooltip", "LootCollectorViewerScanTip", UIParent, "GameTooltipTemplate")
            localWorldforgedScanTip:SetOwner(UIParent, "ANCHOR_NONE")
        end
        tooltip = localWorldforgedScanTip
        tooltipName = "LootCollectorViewerScanTipTextLeft"
    end

    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)

    -- Guard: if the tooltip is incomplete (item data still in flight from
    -- the server), do NOT cache a negative result. The old code scanned an
    -- empty/partial tooltip, cached "false" for the whole session, and the
    -- item stayed misclassified even after its data arrived.
    local numLines = tooltip:NumLines() or 0
    local line1 = _G[tooltipName .. 1]
    local line1Text = line1 and line1:GetText()
    if numLines < 2 or not line1Text or line1Text == RETRIEVING_TEXT then
        return false
    end

    -- Scan ALL lines (the Scanner module does the same). The old 2-5 window
    -- missed the Worldforged tag on tooltips with extra header lines (phase
    -- upgrades, difficulty tags, etc.).
    local isWorldforged = false
    for i = 2, numLines do
        local lineObj = _G[tooltipName .. i]
        local text = lineObj and lineObj:GetText()
        if text and _strfind(text, "orldforged", 1, true) then
            isWorldforged = true
            break
        end
    end

    Cache.worldforged[itemLink] = isWorldforged
    return isWorldforged
end

local function IsMysticScroll(itemName)
    return itemName and _strfind(itemName, "Mystic Scroll", 1, true) ~= nil
end

function Viewer:EnsureVendorInventoryPanel()
    if self.vendorInventoryFrame then
        return
    end

    if not (self.window and self.scrollFrame) then
        return
    end

    local parent = self.window
    local f = CreateFrame("Frame", "LootCollectorViewerVendorInventory", parent)

    f:SetFrameStrata(FRAME_STRATA)
    f:SetFrameLevel((parent:GetFrameLevel() or 1) + 1)
    f:EnableMouse(true)

    
    f:SetPoint("TOPLEFT", self.scrollFrame, "BOTTOMLEFT", 0, -10)

    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)

    f.title = f:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetWidth(400)
    f.title:SetJustifyH("LEFT")
    f.title:SetText("Select a vendor to view inventory")

    
    f.headerRow = CreateFrame("Frame", nil, f)
    f.headerRow:SetHeight(16)
    f.headerRow:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.headerRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -8)

    f.nameHeader = f.headerRow:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    f.nameHeader:SetPoint("LEFT", 8, 0)
    f.nameHeader:SetText("Item Name")
    f.nameHeader:SetTextColor(0.4, 0.6, 1.0)
    f.nameHeader:SetJustifyH("LEFT")

    f.priceHeader = f.headerRow:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    f.priceHeader:SetPoint("RIGHT", -10, 0)
    f.priceHeader:SetText("Price")
    f.priceHeader:SetTextColor(0.4, 0.6, 1.0)
    f.priceHeader:SetJustifyH("RIGHT")

    local invScroll = CreateFrame("ScrollFrame", "LootCollectorViewerVendorInventoryScroll", f, "FauxScrollFrameTemplate")
    invScroll:SetPoint("TOPLEFT", f.headerRow, "BOTTOMLEFT", 0, -4)
    invScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 6)

    f.itemLines = {}
    for i = 1, 40 do 
        local line = CreateFrame("Button", nil, f)
        line:SetHeight(20)
        
        line:SetPoint("RIGHT", invScroll, "RIGHT", 0, 0)
        line:SetPoint("LEFT", invScroll, "LEFT", 8, 0)
        
        if i == 1 then
            line:SetPoint("TOPLEFT", invScroll, "TOPLEFT", 8, 0)
        else
            line:SetPoint("TOPLEFT", f.itemLines[i-1], "BOTTOMLEFT", 0, 0)
        end
        
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetSize(18, 18)
        line.icon:SetPoint("LEFT", 0, 0)
        line.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        line.text = line:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
        line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
        line.text:SetPoint("RIGHT", -80, 0)
        line.text:SetJustifyH("LEFT")
        line.text:SetText("")

        line.priceText = line:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
        line.priceText:SetPoint("RIGHT", line, "RIGHT", -10, 0)
        line.priceText:SetJustifyH("RIGHT")

        line.itemLink = nil
        line.parentVendorData = nil

        line:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
                GameTooltip:SetFrameStrata("TOOLTIP") 
            end
        end)
        line:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

        line:SetScript("OnClick", function(self)
            local Map = L:GetModule("Map", true)
            if IsShiftKeyDown() and self.parentVendorData then
                if Map and Map.IsChatEditBoxOpen and Map:IsChatEditBoxOpen() then
                    if self.itemLink then
                        if Map.LinkDiscoveryItemToChat then
                            Map:LinkDiscoveryItemToChat(nil, self.itemLink)
                        elseif HandleModifiedItemClick then
                            HandleModifiedItemClick(self.itemLink)
                        end
                    end
                    return
                end
                Viewer:ShowOnMap(self.parentVendorData)
                return
            end
            if self.itemLink then
                HandleModifiedItemClick(self.itemLink)
            end
        end)

        line:Hide()
        f.itemLines[i] = line
    end
    
    local function refreshInventory()
        if Viewer.selectedVendorGuid then
            local dbVendors = L:GetVendorsDB()
            local d = dbVendors and dbVendors[Viewer.selectedVendorGuid]
            
            if d and d.vendorItems then
                local zoneName = GetLocalizedZoneName and GetLocalizedZoneName(d) or ""
                if zoneName ~= "" and zoneName ~= "Unknown Zone" then
                    f.title:SetText(d.vendorName .. " – " .. zoneName)
                else
                    f.title:SetText(d.vendorName .. " Inventory")
                end
                
                local numItems = #d.vendorItems
                local visibleInvRows = math.max(1, math.floor((invScroll:GetHeight()) / 20))
                
                FauxScrollFrame_Update(invScroll, numItems, visibleInvRows, 20)
                local offset = FauxScrollFrame_GetOffset(invScroll)
                
                for i = 1, 40 do
                    local line = f.itemLines[i]
                    if i <= visibleInvRows then
                        local idx = offset + i
                        if idx <= numItems then
                            local itemData = d.vendorItems[idx]
                            if itemData then
                                local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemData.link or itemData.itemID or 0)
                                line.icon:SetTexture(texture or itemData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                                line.text:SetText(itemData.link or itemData.name)
                                
                                if itemData.price and itemData.price > 0 then
                                    line.priceText:SetText(GetCoinTextureString(itemData.price))
                                else
                                    line.priceText:SetText("")
                                end

                                line.itemLink = itemData.link
                                line.parentVendorData = d
                                line:Show()
                            else
                                line:Hide()
                            end
                        else
                            line:Hide()
                        end
                    else
                        line:Hide()
                    end
                end
            else
                f.title:SetText("Vendor Inventory")
                FauxScrollFrame_Update(invScroll, 0, 1, 20)
                for _, line in ipairs(f.itemLines) do line:Hide() end
            end
        else
            f.title:SetText("Select a vendor to view inventory")
            FauxScrollFrame_Update(invScroll, 0, 1, 20)
            for _, line in ipairs(f.itemLines) do line:Hide() end
        end
    end

    invScroll:SetScript("OnVerticalScroll", function(s, dlt)
        FauxScrollFrame_OnVerticalScroll(s, dlt, 20, refreshInventory)
    end)
    
    f.refreshInventory = refreshInventory
    f.scrollFrame = invScroll 
    f.vendorItems = {}

    self.vendorInventoryFrame = f
    self.vendorInventoryLines = f.itemLines
    f:Hide()
end

function Viewer:UpdateVendorInventoryScroll()
    if self.vendorInventoryFrame and self.vendorInventoryFrame.refreshInventory then
        self.vendorInventoryFrame.refreshInventory()
    end
end

function Viewer:ShowVendorInventoryForDiscovery(discovery)
    if not discovery then return end
    self:EnsureVendorInventoryPanel()
    if not self.vendorInventoryFrame then return end

    self.selectedVendorGuid = discovery.g
    if self.vendorInventoryFrame.scrollFrame then
        self.vendorInventoryFrame.scrollFrame.offset = 0
        self.vendorInventoryFrame.scrollFrame:SetVerticalScroll(0)
    end
    self:UpdateVendorInventoryScroll()
end

local GetCascadedFilterContext, GetFilteredDatasetForUniqueValues, GetUniqueValues

GetCascadedFilterContext = function(excludeColumn)
    local context = {
        currentFilter = Viewer.currentFilter,
        excludeColumn = excludeColumn,
        hasDeepFilters = Viewer:HasDeepFilters()
    }

    context.activeFilters = {}

    if Viewer.currentFilter == "eq" then
        local filterGroup = Viewer.columnFilters[Viewer.currentFilter]
        if filterGroup then
            if excludeColumn ~= "slot" and size(filterGroup.slot) > 0 then
                context.activeFilters.slot = filterGroup.slot
            end
            if excludeColumn ~= "type" and size(filterGroup.type) > 0 then
                context.activeFilters.type = filterGroup.type
            end
            if excludeColumn ~= "class" and size(filterGroup.class) > 0 then
                context.activeFilters.class = filterGroup.class
            end
        end
    elseif Viewer.currentFilter == "ms" then
        if excludeColumn ~= "class" and size(Viewer.columnFilters.ms.class) > 0 then
            context.activeFilters.class = Viewer.columnFilters.ms.class
        end
    end

    if excludeColumn ~= "zone" and size(Viewer.columnFilters.zone) > 0 then
        context.activeFilters.zone = Viewer.columnFilters.zone
    end

    if excludeColumn ~= "source" and size(Viewer.columnFilters.source) > 0 then
        context.activeFilters.source = Viewer.columnFilters.source
    end

    if excludeColumn ~= "quality" then
        if size(Viewer.columnFilters.quality) > 0 then
            context.activeFilters.quality = Viewer.columnFilters.quality
        end
    end

    if excludeColumn ~= "looted" and size(Viewer.columnFilters.looted) > 0 then
        context.activeFilters.looted = Viewer.columnFilters.looted
    end

    if excludeColumn ~= "vendorType" and size(Viewer.columnFilters.vendorType) > 0 then
        context.activeFilters.vendorType = Viewer.columnFilters.vendorType
    end

    if excludeColumn ~= "duplicates" and Viewer.columnFilters.duplicates then
        context.activeFilters.duplicates = { enabled = true }
    end

    return context
end

local function removeFromSpecialFrames(windowName)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == windowName then
            _tremove(UISpecialFrames, i)
            return true
        end
    end
    return false
end

local function addToSpecialFrames(windowName)
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == windowName then
            return false 
        end
    end
    _tinsert(UISpecialFrames, windowName)
    return true
end

GetFilteredDatasetForUniqueValues = function(context)
    local filteredData = {}
    
    
    for i = 1, #Cache.discoveries do
        local data = Cache.discoveries[i]
        if data then
            local passed = true

            local Constants = L:GetModule("Constants", true)
            -- FIXED: mirror mainFilter's guard -- undiscovered placeholder
            -- rows live at c=0/z=0, which IsForbiddenZone treats as
            -- forbidden, so they were silently excluded from the datasets
            -- that build the slot/type/class/zone dropdown options.
            -- Vendors are exempt (they stand in cities legitimately).
            if not data.isUndiscovered and not data.isVendor and Constants and Constants.IsForbiddenZone and Constants:IsForbiddenZone(data.discovery.c, data.discovery.z, data.discovery.fp) then
                passed = false
            end
            -- CoA realms removed relics (Librams/Idols/Totems).
            if passed and data.equipLoc == "INVTYPE_RELIC" then
                local CoreM = L:GetModule("Core", true)
                if CoreM and CoreM.IsConfirmedCoARealm and CoreM:IsConfirmedCoARealm() then
                    passed = false
                end
            end
            
            if passed and context.currentFilter == "eq" then
                if data.isVendor or data.isMystic then passed = false end
            elseif context.currentFilter == "ms" then
                if data.isVendor or not data.isMystic then passed = false end
            elseif context.currentFilter == "bmv" then
                if not data.isVendor or data.vendorType ~= "BM" then passed = false end
            elseif context.currentFilter == "msv" then
                if not data.isVendor or data.vendorType ~= "MS" then passed = false end
            end

            if passed and context.hasDeepFilters then
                if not Viewer:MatchesDeepFilterOnRow(data) then passed = false end
            end

            if passed and context.activeFilters.slot then
                local slotValue = data.equipLoc and _G[data.equipLoc] or ""
                if not context.activeFilters.slot[slotValue] then passed = false end
            end

            if passed and context.activeFilters.type then
                if not DiscoveryMatchesTypeFilter(data, context.activeFilters.type) then passed = false end
            end

            if passed and context.activeFilters.class then
                if context.currentFilter == "eq" then
                    if Constants and Constants.CLASS_PROFICIENCIES then
                        local subTypeID = data.ist
                        local typeID = data.it
                        
                        if subTypeID and typeID and subTypeID > 0 and typeID > 0 then
                            local canUse = false
                            for classFilterName, _ in pairs(context.activeFilters.class) do
                                 local classToken = nil
                                 if _G.LOCALIZED_CLASS_NAMES_MALE then
                                     for token, locName in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
                                         if locName == classFilterName then classToken = token; break end
                                     end
                                 end
                                 if not classToken and _G.LOCALIZED_CLASS_NAMES_FEMALE then
                                     for token, locName in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
                                         if locName == classFilterName then classToken = token; break end
                                     end
                                 end
                                 if not classToken then classToken = string.upper(classFilterName) end
                                 
                                 local profs = Constants.CLASS_PROFICIENCIES[classToken]
                                 if profs then
                                     local list = nil
                                     if typeID == Constants.ITEM_TYPE_TO_ID["Armor"] then list = profs.armor
                                     elseif typeID == Constants.ITEM_TYPE_TO_ID["Weapon"] then list = profs.weapons end
                                     
                                     if list then
                                         for _, allowedID in ipairs(list) do
                                             if subTypeID == allowedID then canUse = true; break end
                                         end
                                     else
                                         canUse = true 
                                     end
                                 end
                                 if canUse then break end
                            end
                            if not canUse then passed = false end
                        else
                            passed = false
                        end
                    end
                else
                    local classValue = data.characterClass or ""
                    if data.cl and data.cl ~= "cl" then
                        local classToken = CLASS_ABBREVIATIONS_REVERSE[data.cl]
                        if classToken then
                            classValue = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
                        end
                    end
                    if classValue == "" then classValue = data.characterClass or "" end
                    if not context.activeFilters.class[classValue] then passed = false end
                end
            end

            if passed and context.activeFilters.zone then
                local zoneValue = GetLocalizedZoneName(data.discovery)
                if not context.activeFilters.zone[zoneValue] then passed = false end
            end

            if passed and context.activeFilters.source then
                local source = data.discovery.src or "unknown"
                local sourceValue = SOURCE_NAMES[source] or source
                if not context.activeFilters.source[sourceValue] then passed = false end
            end

            if passed and context.activeFilters.quality then
                local _, _, quality = GetItemInfoSafe(data.discovery.il, data.discovery.i)
                if not quality then
                    if not context.activeFilters.quality["Unknown"] then passed = false end
                else
                    local qualityValue = QUALITY_NAMES[quality] or ("Quality " .. tostring(quality))
                    if not context.activeFilters.quality[qualityValue] then passed = false end
                end
            end

            if passed and Viewer.lootedFilterState ~= nil then
                local isLooted = Viewer:IsLootedByChar(data.guid)
                if Viewer.lootedFilterState == true and not isLooted then passed = false end
                if Viewer.lootedFilterState == false and isLooted then passed = false end
            end

            if passed and Viewer.fadeFilterState and not data.isVendor then
                if not PassesFadeFilter(data.discovery) then passed = false end
            end

            if passed and Viewer.collectedMEFilterState ~= nil then
                if Constants and data.discovery.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL then
                    if data.discovery.i and data.discovery.i > 0 then
                        local isCollectedME = L:IsMysticEnchantCollected(data.discovery.i)
                        if Viewer.collectedMEFilterState == true and not isCollectedME then passed = false end
                        if Viewer.collectedMEFilterState == false and isCollectedME then passed = false end
                    end
                else
                    if Viewer.collectedMEFilterState == true then passed = false end
                end
            end

            if passed and context.activeFilters.duplicates then
                if not Cache.duplicateItems[data.discovery.i] or Cache.duplicateItems[data.discovery.i] <= 1 then
                    passed = false
                end
            end

            if passed then
                table.insert(filteredData, data)
            end
        end
    end

    return filteredData
end

GetUniqueValues = function(column)
    local context = GetCascadedFilterContext(column)
    local deepKey = ""
    if context.hasDeepFilters and Viewer.deepSearchFilters then
        local dsf = {}
        for i = 1, #Viewer.deepSearchFilters do dsf[i] = string.lower(Viewer.deepSearchFilters[i]) end
        _tsort(dsf)
        deepKey = _tconcat(dsf, "|")
    end
    local cacheKey = column .. ":" .. context.currentFilter .. ":" .. deepKey

    local filterKeys = {}
    for filterType, filters in pairs(context.activeFilters) do
        if filterType == "duplicates" then
            _tinsert(filterKeys, filterType .. "=enabled")
        else
            local sortedKeys = keys(filters)
            _tsort(sortedKeys)
            _tinsert(filterKeys, filterType .. "=" .. _tconcat(sortedKeys, ","))
        end
    end
    if size(filterKeys) > 0 then
        cacheKey = cacheKey .. ":" .. _tconcat(filterKeys, "|")
    end

    if not Cache.uniqueValuesContext then
        Cache.uniqueValuesContext = {}
    end

    if Cache.uniqueValuesContext[cacheKey] then
        return Cache.uniqueValuesContext[cacheKey]
    end
    
    if column == "class" and Viewer.currentFilter == "eq" then
         local values = {}
         local Constants = L:GetModule("Constants", true)
         local activeClasses = Constants and Constants:GetActiveClasses() or CLASS_OPTIONS
         
         for _, classToken in ipairs(activeClasses) do
             if classToken ~= "HERO" then 
                 local locName = Constants and Constants:GetLocalizedClassName(classToken) or classToken
                 _tinsert(values, locName)
             end
         end
         
         _tsort(values)
         Cache.uniqueValuesContext[cacheKey] = values
         return values
    end

    local filteredDataset = GetFilteredDatasetForUniqueValues(context)
    local values = {}
    local seen = {}

    if column == "zone" then
        local ZoneList = L:GetModule("ZoneList", true)
        local zoneByKey = {}

        for _, data in ipairs(filteredDataset) do
            local discovery = data.discovery
            if discovery then
                local c = tonumber(discovery.c) or 0
                local z = tonumber(discovery.z) or 0
                local iz = tonumber(discovery.iz) or 0
                local key = string.format("%d:%d:%d", c, z, iz)
                
                if not zoneByKey[key] then
                    zoneByKey[key] = { c = c, z = z, iz = iz }
                end
            end
        end

        for key, zoneData in pairs(zoneByKey) do
            local localizedZoneName = GetLocalizedZoneName(zoneData)
            if localizedZoneName and localizedZoneName ~= "" and not seen[localizedZoneName] then
                seen[localizedZoneName] = true
                _tinsert(values, localizedZoneName)
            end
        end
    else
        local NUMERIC_SOURCE_MAP = {
            [0] = "world_loot",
            [1] = "npc_gossip",
            [2] = "emote_event",
            [3] = "direct",
        }

       local columnExtractor = {
            slot = function(data) return data.equipLoc and _G[data.equipLoc] or "" end,
            type = function(data) return data.itemSubType or "" end,
            class = function(data)
                if data.cl and data.cl ~= "cl" then
                    local classToken = CLASS_ABBREVIATIONS_REVERSE[data.cl]
                    if classToken then
                        return _G.LOCALIZED_CLASS_NAMES_MALE[classToken] or _G.LOCALIZED_CLASS_NAMES_FEMALE[classToken] or ""
                    end
                end
                return data.characterClass or ""
            end,
            source = function(data)
                local raw = data.discovery.src
                if type(raw) == "number" then
                    raw = NUMERIC_SOURCE_MAP[raw] or "unknown"
                end
                local sourceKey = raw or "unknown"
                return SOURCE_NAMES[sourceKey] or tostring(sourceKey)
            end,
            quality = function(data)
                local _, _, quality = GetItemInfoSafe(data.discovery.il, data.discovery.i)
                if not quality then return "Unknown" end
                return QUALITY_NAMES[quality] or ("Quality " .. tostring(quality))
            end,
            looted = function(data)
                return Viewer:IsLootedByChar(data.guid) and "Looted" or "Not Looted"
            end,
            vendorType = function(data)
                local typeMap = { ["BM"] = "Blackmarket", ["MS"] = "Mystic Enchants" }
                local vType = data.vendorType or (data.discovery and data.discovery.vendorType)
                if not vType and data.discovery and data.discovery.g then
                    if data.discovery.g:find("BM-", 1, true) then vType = "BM"
                    elseif data.discovery.g:find("MS-", 1, true) then vType = "MS"
                    end
                end
                return typeMap[vType] or vType or "Unknown"
            end
        }

        local extractor = columnExtractor[column]
        if extractor then
            for _, data in ipairs(filteredDataset) do
                local value = extractor(data)
                if value and value ~= "" and not seen[value] then
                    seen[value] = true
                    _tinsert(values, value)
                end
            end
        end
    end

    if column == "quality" then
        local qualityOrder = {
            ["Heirloom"] = 7,
            ["Artifact"] = 6,
            ["Legendary"] = 5,
            ["Epic"] = 4,
            ["Rare"] = 3,
            ["Uncommon"] = 2,
            ["Common"] = 1,
            ["Poor"] = 0,
            ["Unknown"] = -1
        }
        _tsort(values, function(a, b)
            local aOrder = qualityOrder[a] or 999
            local bOrder = qualityOrder[b] or 999
            return aOrder > bOrder 
        end)
    else
        _tsort(values)
    end

    Cache.uniqueValuesContext[cacheKey] = values
    return values
end

local scanQueue = {}
local scanCursor = 0
local scanProgressCallback = nil

local STATUS_UNCONFIRMED = "UNCONFIRMED"
local STATUS_CONFIRMED = "CONFIRMED"
local STATUS_FADING = "FADING"
local STATUS_STALE = "STALE"

local function HasDataChanged()
    local discoveries = L:GetDiscoveriesDB()
    if not discoveries then
        return false
    end

    local currentCount = 0
    for _ in pairs(discoveries) do
        currentCount = currentCount + 1
    end

    if not Cache.lastDiscoveryCount then
        Cache.lastDiscoveryCount = currentCount
        return true 
    end

    local hasChanged = Cache.lastDiscoveryCount ~= currentCount
    if hasChanged then
        Cache.lastDiscoveryCount = currentCount
    end

    return hasChanged
end

function Viewer:SetUIEnabled(enabled)
    if not self.window or not self.interactiveElements then return end

    local Core = L:GetModule("Core", true)
    local isCoA = Core and Core.IsConfirmedCoARealm and Core:IsConfirmedCoARealm()

    for _, element in ipairs(self.interactiveElements) do
        if element then
            local isMsButton = (element == self.mysticBtn)
            if isMsButton and isCoA then
                element:Disable()
            else
                if enabled then
                    element:Enable()
                else
                    element:Disable()
                end
            end
        end
    end

    if self.searchClearBtn then
        if enabled then
            self.searchClearBtn:Enable()
        else
            self.searchClearBtn:Disable()
        end
    end
end

local function CreateContextMenu(anchor, title, buttons, options)
    options = options or {}
    local menuWidth = options.width or CONTEXT_MENU_WIDTH
    local menuHeight = options.height or (20 + 5 + (25 * #buttons) + 20) 

    if Viewer.contextMenu then
        Viewer.contextMenu:Hide()
        Viewer.contextMenu = nil
    end

    local contextMenu = CreateFrame("Frame", "LootCollectorViewerContextMenu", Viewer.window)
    contextMenu:SetSize(menuWidth, menuHeight)

    if anchor.mouseX and anchor.mouseY then
        local uiScale = UIParent:GetEffectiveScale()
        contextMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            anchor.mouseX / uiScale, anchor.mouseY / uiScale)
    else
        contextMenu:SetPoint("LEFT", anchor, "RIGHT", 5, 0)
    end

    contextMenu:SetFrameStrata("DIALOG")
    contextMenu:EnableMouse(true)

    contextMenu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    contextMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.98)

    local titleText = contextMenu:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    titleText:SetPoint("TOPLEFT", 10, -10)
    titleText:SetText(title)
    titleText:SetTextColor(1, 1, 1)

    local separator = contextMenu:CreateTexture(nil, "OVERLAY")
    separator:SetSize(menuWidth - 20, 1)
    separator:SetPoint("TOPLEFT", 10, -30)
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.8)

    local lastButton = nil
    for i, buttonData in ipairs(buttons) do
        local btn = CreateFrame("Button", nil, contextMenu, "UIPanelButtonTemplate")
        btn:SetSize(menuWidth - 20, 20) 
        btn:SetFrameLevel(contextMenu:GetFrameLevel() + 1)
        if lastButton then
            btn:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, -5)
        else
            btn:SetPoint("TOPLEFT", 10, -40)
        end
        btn:SetText(buttonData.text)
        
        local btnText = btn:GetFontString()
        if btnText then
            btnText:SetFontObject(UI_FONT_NAME)
        end
        
        btn:SetScript("OnClick", function()
            if buttonData.onClick then
                buttonData.onClick()
            end
            contextMenu:Hide()
            Viewer.contextMenu = nil
        end)
        lastButton = btn
    end

    contextMenu:SetScript("OnLeave", function(self)
        createTimer(0.1, function()
            if Viewer.contextMenu and Viewer.contextMenu:IsShown() then
                local contextMenuMouseOver = Viewer.contextMenu:IsMouseOver()
                local anchorMouseOver = anchor:IsMouseOver()
                
                if not contextMenuMouseOver and not anchorMouseOver then
                    Viewer.contextMenu:Hide()
                    Viewer.contextMenu = nil
                end
            end
        end)
    end)

    contextMenu:Show()
    Viewer.contextMenu = contextMenu

    local function OnMouseDown(self, button)
        if Viewer.contextMenu and not Viewer.contextMenu:IsMouseOver() and not anchor:IsMouseOver() then
            Viewer.contextMenu:Hide()
            Viewer.contextMenu = nil
        end
    end
    UIParent:SetScript("OnMouseDown", OnMouseDown)
    contextMenu:SetScript("OnHide", function()
        UIParent:SetScript("OnMouseDown", nil)
    end)

    return contextMenu
end

local MAX_LEVELS = 4
local lastAnchor = {}

local function GetEstimatedListHeight(list)
    local h = list:GetHeight()
    if h and h > 0 then return h end
    local name = list:GetName()
    local total = 0
    if name then
        for i = 1, (list.numButtons or 32) do
            local btn = _G[name .. "Button" .. i]
            if not btn then break end
            local bh = btn:GetHeight() or 0
            if bh == 0 then bh = 16 end
            total = total + bh
        end
    end
    if total > 0 then return total end
    return (list.numButtons or 20) * (list.buttonHeight or 16)
end

local function IsCursorAnchor(anchor)
    if not anchor then return false end
    if type(anchor) == "string" then
        local a = anchor:lower()
        return a:find("cursor") or a:find("mouse")
    end
    return false
end

local function RepositionList(level, dropDownFrame, anchorTo)
    local list = _G["DropDownList" .. (tonumber(level) or 1)]
    if not list then return end

    local needed = GetEstimatedListHeight(list)
    local screenBottom = (UIParent and UIParent:GetBottom()) or 0

    if IsCursorAnchor(anchorTo) then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x = x / scale
        y = y / scale
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y - 10)
        list:SetClampedToScreen(true)
        return
    end

    local anchorFrame = nil
    if type(anchorTo) == "table" and anchorTo.GetBottom then
        anchorFrame = anchorTo
    elseif dropDownFrame and dropDownFrame.GetBottom then
        anchorFrame = dropDownFrame
    elseif type(anchorTo) == "string" then
        anchorFrame = dropDownFrame or UIParent
    else
        anchorFrame = dropDownFrame or UIParent
    end

    local frameBottom = (anchorFrame and anchorFrame.GetBottom and anchorFrame:GetBottom()) or 0
    local spaceBelow = frameBottom - screenBottom

    if spaceBelow >= needed then
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, 0)
        list:SetClampedToScreen(true)
    end
end

hooksecurefunc("ToggleDropDownMenu", function(level, value, dropDownFrame, anchorTo, xOffset, yOffset)
    level = tonumber(level) or 1
    lastAnchor[level] = { dropDownFrame = dropDownFrame, anchorTo = anchorTo }
    local list = _G["DropDownList" .. level]
    if list and list:IsShown() then
        RepositionList(level, dropDownFrame, anchorTo)
    end
end)

for i = 1, MAX_LEVELS do
    local list = _G["DropDownList" .. i]
    if list then
        list:HookScript("OnShow", function(self)
            local info = lastAnchor[i] or {}
            RepositionList(i, info.dropDownFrame, info.anchorTo)
        end)
    end
end

function Viewer:ShowColumnFilterDropdown(column, anchor, values)
    local dropdownList = _G["DropDownList1"]
    if Viewer.currentFilterAnchor == anchor and dropdownList and dropdownList:IsShown() then
        HideDropDownMenu(1)
        Viewer.currentFilterAnchor = nil
        return
    end
    Viewer.currentFilterAnchor = anchor

    HideDropDownMenu(1)
    if not values or #values == 0 then
        local fallbackValues = {}
        if Cache.discoveriesBuilt then
            local seen = {}
            if column == "zone" then
                local ZoneList = L:GetModule("ZoneList", true)
                local zoneByKey = {}
                for _, data in ipairs(Cache.discoveries) do
                    local discovery = data.discovery
                    if discovery then
                        local c = tonumber(discovery.c) or 0
                        local z = tonumber(discovery.z) or 0
                        local iz = tonumber(discovery.iz) or 0
                        local key = string.format("%d:%d:%d", c, z, iz)
                        if not zoneByKey[key] then zoneByKey[key] = { c = c, z = z, iz = iz } end
                    end
                end
                for key, zoneData in pairs(zoneByKey) do
                    local localizedZoneName = GetLocalizedZoneName(zoneData)
                    if localizedZoneName and localizedZoneName ~= "" and not seen[localizedZoneName] then
                        seen[localizedZoneName] = true
                        _tinsert(fallbackValues, localizedZoneName)
                    end
                end
            else
                local NUMERIC_SOURCE_MAP = { [0]="world_loot", [1]="npc_gossip", [2]="emote_event", [3]="direct" }
                local columnExtractor = {
                    slot = function(data) return data.equipLoc and _G[data.equipLoc] or "" end,
                    type = function(data) return data.itemSubType or "" end,
                    class = function(data) return data.characterClass or "" end,
                    source = function(data)
                        local raw = data.discovery.src
                        if type(raw) == "number" then raw = NUMERIC_SOURCE_MAP[raw] or "unknown" end
                        local sourceKey = raw or "unknown"
                        return SOURCE_NAMES[sourceKey] or tostring(sourceKey)
                    end,
                    quality = function(data)
                        local _, _, quality = GetItemInfoSafe(data.discovery.il, data.discovery.i)
                        if not quality then return "Unknown" end
                        return QUALITY_NAMES[quality] or ("Quality " .. tostring(quality))
                    end,
                    looted = function(data) return Viewer:IsLootedByChar(data.guid) and "Looted" or "Not Looted" end,
                    vendorType = function(data)
                        local typeMap = { ["BM"] = "Blackmarket", ["MS"] = "Mystic Enchants" }
                        local vType = data.vendorType or (data.discovery and data.discovery.vendorType)
                        if not vType and data.discovery and data.discovery.g then
                            if data.discovery.g:find("BM-", 1, true) then vType = "BM"
                            elseif data.discovery.g:find("MS-", 1, true) then vType = "MS" end
                        end
                        return typeMap[vType] or vType or "Unknown"
                    end
                }
                local extractor = columnExtractor[column]
                if extractor then
                    for _, data in ipairs(Cache.discoveries) do
                        local value = extractor(data)
                        if value and value ~= "" and not seen[value] then
                            seen[value] = true
                            _tinsert(fallbackValues, value)
                        end
                    end
                end
            end
            _tsort(fallbackValues)
        end
        values = fallbackValues
    end

    if not values or #values == 0 then return end
    
    local filterTable
    if column == "zone" then filterTable = Viewer.columnFilters.zone
    elseif column == "source" then filterTable = Viewer.columnFilters.source
    elseif column == "quality" then filterTable = Viewer.columnFilters.quality
    elseif column == "looted" then filterTable = Viewer.columnFilters.looted
    elseif column == "vendorType" then filterTable = Viewer.columnFilters.vendorType
    else filterTable = Viewer.columnFilters[Viewer.currentFilter][column] end

    local dropdown = CreateFrame("Frame", "LootCollectorViewerFilterDropdown", Viewer.window, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local clearAllInfo = {
            text = "Clear All Filters",
            notCheckable = true,
            func = function()
                Viewer:ClearDiscoveriesFilters()
                HideDropDownMenu(1)
            end
        }
        UIDropDownMenu_AddButton(clearAllInfo, level)

        local separatorInfo = { text = "", notCheckable = true, disabled = true }
        UIDropDownMenu_AddButton(separatorInfo, level)

        for _, value in ipairs(values) do
            local isChecked = false
            if filterTable then isChecked = filterTable[value] ~= nil end

            local displayText = value
            if column == "quality" then
                local useWCAG = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.useWCAGColoring
                if useWCAG == nil then useWCAG = true end

                local map
                if useWCAG then
                    map = { 
                        ["Poor"] = "FFA09C93", 
                        ["Common"] = "FFFFFFFF", 
                        ["Uncommon"] = "FF1EFF00", 
                        ["Rare"] = "FF54B2FF", 
                        ["Epic"] = "FFC884FF", 
                        ["Legendary"] = "FFFF8000", 
                        ["Artifact"] = "FFCBAE77", 
                        ["Heirloom"] = "FFE6CC80" 
                    }
                else
                    map = { 
                        ["Poor"] = "FF605C53", 
                        ["Common"] = "FFFFFFFF", 
                        ["Uncommon"] = "FF1EFF00", 
                        ["Rare"] = "FF0070DD", 
                        ["Epic"] = "FFA335EE", 
                        ["Legendary"] = "FFFF8000", 
                        ["Artifact"] = "FFCBAE77", 
                        ["Heirloom"] = "FFE6CC80" 
                    }
                end
                local hex = map[value] or "FFFFFFFF"
                displayText = "|c" .. hex .. value .. "|r"
            elseif column == "class" then
                local classFileName = value:upper():gsub("%s+", "")
                local Constants = L:GetModule("Constants", true)
                if Constants and Constants.GetClassTokenFromLocalizedName then
                    local foundToken = Constants:GetClassTokenFromLocalizedName(value)
                    if foundToken ~= value then classFileName = foundToken end
                end

                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName]
                if not color and CUSTOM_CLASS_COLORS then color = CUSTOM_CLASS_COLORS[classFileName] end

                if color then displayText = string.format("|cFF%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, value) end
            end

            local info = {
                text = displayText,
                checked = isChecked,
                func = function()
                    if not filterTable then return end
                    if filterTable[value] then filterTable[value] = nil else filterTable[value] = true end

                    Viewer.currentPage = 1
                    Cache.filteredResults = {}
                    Cache.lastFilterState = nil
                    Cache.uniqueValuesValid = false
                    Cache.uniqueValuesContext = {} 
                    Viewer:UpdateSortHeaders()
                    Viewer:RefreshData()
                    Viewer:UpdateClearAllButton()
                    Viewer:UpdateFilterButtonStates()
                    HideDropDownMenu(1)
                end
            }
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")

    ToggleDropDownMenu(1, nil, dropdown, anchor, 0, 0)

    local dropdownList = _G["DropDownList1"]
    if dropdownList then
        dropdownList:SetScript("OnLeave", function(self)
            createTimer(0.1, function()
                if dropdownList and dropdownList:IsShown() then
                    local dropdownMouseOver = dropdownList:IsMouseOver()
                    local anchorMouseOver = anchor:IsMouseOver()
                    if not dropdownMouseOver and not anchorMouseOver then
                        HideDropDownMenu(1)
                    end
                end
            end)
        end)
    end
end

-- Silent DB purge during Viewer rebuild: keep ZoneIndex/mid-index in sync
-- without SendMessage (would re-light Refresh after rebuild).
local function SilentPurgeDiscovery(guid)
    local db = L:GetDiscoveriesDB()
    if not (db and guid and db[guid]) then return end
    local d = db[guid]
    local Core = L:GetModule("Core", true)
    if Core and Core.UnindexDiscovery then
        Core:UnindexDiscovery(guid, d)
    end
    db[guid] = nil
    L.DataHasChanged = true
end

-- Fill a Viewer cache row from a discovery/vendor record.
-- opts: isVendor, isUndiscovered, allowDBPurge (rebuild-time silent purge)
-- Returns true if the row was filled and should be kept.
local function FillDiscoveryRow(row, guid, discovery, opts)
    opts = opts or {}
    local isVendor = opts.isVendor
    local isUndiscovered = opts.isUndiscovered
    local allowDBPurge = opts.allowDBPurge
    local Core = L:GetModule("Core", true)

    if isVendor then
        wipe(row)
        row.guid       = guid
        row.discovery  = discovery
        row.isVendor   = true
        row.vendorType = discovery.vendorType
        row.vendorName = discovery.vendorName
        row.isMystic   = false
        row.itemName   = discovery.vendorName
        row.zoneNameStr = GetLocalizedZoneName(discovery)
        row.sortQuality = 7
        row.sortName    = discovery.vendorName or ""
        row.sortClass   = ""
        local vType = discovery.vendorType
        if not vType and discovery.g then
            if discovery.g:find("MS-", 1, true) then vType = "MS"
            else vType = "BM" end
        end
        row.sortType = vType or "BM"
        row.sortSlot = ""
        return true
    end

    local itemLink = discovery.il
    local itemID = discovery.i
    local selectedPhase = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.worldforgedPhase or 0
    if selectedPhase > 0 and L:IsWorldforgedUpgradeable(itemID) then
        local upgradedID = L:GetWorldforgedPhaseItemID(itemID, selectedPhase)
        if upgradedID and upgradedID ~= itemID then
            itemID = upgradedID
            itemLink = nil
        end
    end

    local itemName = nil
    if (not itemLink or itemLink == "") and itemID then
        local name, link = GetItemInfo(itemID)
        if link then itemLink = link end
    end
    if itemLink and itemLink ~= "" then
        itemName = itemLink:match("%[(.+)%]")
    end
    if (not itemName or itemName == "") and itemID then
        itemName = GetItemInfo(itemID)
    end
    if not itemName or itemName == "" then
        if itemID then
            itemName = "Unknown Item (" .. tostring(itemID) .. ")"
        else
            itemName = "Unknown Item"
        end
        Viewer.hasUncachedData = true
    end

    if isUndiscovered then
        local isCoA = Core and Core.IsConfirmedCoARealm and Core:IsConfirmedCoARealm()
        if isCoA then
            local _, _, _, _, _, _, _, _, eqLoc = GetItemInfo(discovery.i)
            if eqLoc == "INVTYPE_RELIC" then
                return false
            end
        end
    end

    local Scanner = L:GetModule("Scanner", true)
    local itemData = {}
    if Scanner then
        local ok, res = pcall(Scanner.GetItemData, Scanner, discovery.i, itemLink)
        if ok and res then itemData = res end
    end

    local isMystic = IsMysticScroll(itemName)
    local isWorldforged = itemData.isWF or false
    if isUndiscovered then
        isWorldforged = true
    elseif not isWorldforged then
        local baseLink = discovery.il
        if (not baseLink or baseLink == "") and discovery.i then
            baseLink = select(2, GetItemInfo(discovery.i))
        end
        if baseLink and baseLink ~= "" then
            isWorldforged = IsWorldforged(baseLink)
        end
    end

    local characterClass = ""
    local classToken = itemData.classToken
    if classToken then
        characterClass = _G.LOCALIZED_CLASS_NAMES_MALE[classToken] or _G.LOCALIZED_CLASS_NAMES_FEMALE[classToken] or classToken
        local Constants = L:GetModule("Constants", true)
        if Constants and Constants.CLASS_ABBREVIATIONS[classToken] then
            local correctAbbr = Constants.CLASS_ABBREVIATIONS[classToken]
            if discovery.cl ~= correctAbbr then
                discovery.cl = correctAbbr
                L.DataHasChanged = true
            end
        end
    end

    local name, _, _, itemLevelVal, minLevel, itemTypeVal, itemSubTypeVal, _, equipLocVal = GetItemInfoSafe(itemLink, itemID)
    if (not name) and discovery.i and itemID ~= discovery.i then
        local bName, _, _, bIlvl, bMinLvl, bType, bSubType, _, bEquip = GetItemInfo(discovery.i)
        if bName then
            itemLevelVal   = itemLevelVal or bIlvl
            minLevel       = minLevel or bMinLvl
            itemTypeVal    = itemTypeVal or bType
            itemSubTypeVal = itemSubTypeVal or bSubType
            equipLocVal    = equipLocVal or bEquip
            if not itemName or itemName == "" or _strfind(itemName, "Unknown Item", 1, true) then
                itemName = bName
            end
        end
    end

    local finalMinLevel = itemData.reqLevel or minLevel or 0

    if not isUndiscovered then
        local dx = discovery.xy and discovery.xy.x or 0
        local dy = discovery.xy and discovery.xy.y or 0
        if dx == 0 and dy == 0 then
            if allowDBPurge then SilentPurgeDiscovery(guid) end
            return false
        elseif L.StarterDBItemZones and L.StarterDBItemZones[discovery.i] and not L.StarterDBItemZones[discovery.i][discovery.z] then
            if allowDBPurge then SilentPurgeDiscovery(guid) end
            return false
        else
            local Constants = L:GetModule("Constants", true)
            if Constants and Constants.IsLocationValidForItem then
                if not Constants:IsLocationValidForItem(discovery.z, 0, false) then
                    if allowDBPurge then SilentPurgeDiscovery(guid) end
                    return false
                end
            end
        end
    end

    local it, ist = discovery.it, discovery.ist
    if not it or not ist or it == 0 or ist == 0 then
        it, ist = GetItemTypeIDs(itemTypeVal, itemSubTypeVal)
    end
    if not itemTypeVal and not isMystic then
        Viewer.hasUncachedData = true
    end

    wipe(row)
    row.guid          = guid
    row.discovery     = discovery
    row.displayItemID = itemID
    row.itemName      = itemName
    row.isMystic      = isMystic
    local isNew = isUndiscovered or false
    if not isNew and discovery.i and L.db and L.db.global and L.db.global.newWorldforgedItems then
        isNew = L.db.global.newWorldforgedItems[discovery.i] or false
    end
    row.isNew = isNew
    row.isWorldforged = isNew and true or isWorldforged
    row.isUndiscovered = isUndiscovered or false
    row.itemType      = itemTypeVal
    row.itemSubType   = itemSubTypeVal
    row.it            = it
    row.ist           = ist
    row.equipLoc      = equipLocVal
    row.characterClass= characterClass
    row.itemLevel     = itemLevelVal
    row.minLevel      = finalMinLevel
    row.cl            = discovery.cl
    row.isVendor      = false
    row.tooltipText   = itemData.fullText or ""
    row.zoneNameStr   = isUndiscovered and "Undiscovered" or GetLocalizedZoneName(discovery)
    row.sortQuality   = isUndiscovered and (select(3, GetItemInfo(discovery.i)) or 2) or (tonumber(discovery.q) or 1)
    row.sortName      = itemName or ""
    row.sortClass     = characterClass or ""
    row.sortType      = itemSubTypeVal or ""
    row.sortSlot      = equipLocVal and _G[equipLocVal] or ""

    if Core and itemID and not Core:IsItemCached(itemID) then
        Core:QueueItemForCaching(itemID)
    end
    if Core and discovery.i and discovery.i ~= itemID and not Core:IsItemCached(discovery.i) then
        Core:QueueItemForCaching(discovery.i)
    end

    return true
end

local function RebuildDiscoveriesByGuid()
    wipe(Cache.discoveriesByGuid)
    for i = 1, #Cache.discoveries do
        local r = Cache.discoveries[i]
        if r and r.guid then
            Cache.discoveriesByGuid[r.guid] = i
        end
    end
end

-- Cached GetFilterStateHash: rebuild only when filters change or the
-- filtered-result cache was dropped (lastFilterState == nil).
local _filterHashDirty = true
local _cachedFilterHash = nil
local _filterHashFingerprint = nil
local _hashParts = {}
local _filterEntries = {}
local FLAT_FILTER_KEYS = { zone = true, source = true, quality = true, looted = true, vendorType = true }

local function InvalidateViewerFilterCache()
    Cache.filteredResults = {}
    Cache.lastFilterState = nil
    Cache.uniqueValuesValid = false
    _filterHashDirty = true
    if Viewer.InvalidateArrowFilterCache then
        Viewer:InvalidateArrowFilterCache()
    end
end

local function AdjustDuplicateCount(itemID, delta)
    if not itemID then return end
    local n = (Cache.duplicateItems[itemID] or 0) + delta
    if n <= 0 then
        Cache.duplicateItems[itemID] = nil
    else
        Cache.duplicateItems[itemID] = n
    end
end

local function RemoveCacheRowAtIndex(index)
    local n = #Cache.discoveries
    local row = Cache.discoveries[index]
    if not row or index < 1 or index > n then return nil end

    local removedGuid = row.guid
    local removedBase = nil
    if row.discovery and row.discovery.i and not row.isVendor then
        AdjustDuplicateCount(row.discovery.i, -1)
        if not row.isUndiscovered then
            removedBase = L:GetBaseItemID(row.discovery.i)
        end
    end

    if removedGuid then
        Cache.discoveriesByGuid[removedGuid] = nil
    end

    if index < n then
        local last = Cache.discoveries[n]
        Cache.discoveries[index] = last
        Cache.discoveries[n] = nil
        if last and last.guid then
            Cache.discoveriesByGuid[last.guid] = index
        end
    else
        Cache.discoveries[n] = nil
    end

    return removedBase
end

function Viewer:UpdateAllDiscoveriesCache(onCompleteCallback)
    -- FIXED: this entry point used to fill a local scanQueue that
    -- ProcessCacheBuildChunk never read (it consumes self._cacheBuildQueue),
    -- so every "async" rebuild completed instantly against an empty queue
    -- and left the viewer cache empty-but-marked-built. All rebuilds now
    -- delegate to the single chunked builder below.
    VDebug("UpdateAllDiscoveriesCache: delegating to chunked builder")

    if Cache.discoveriesBuilding then
        -- A build is already in flight; adopt the callback instead of
        -- restarting mid-chunk (restarts corrupt the build cursor).
        if onCompleteCallback then
            self.scanProgressCallback = onCompleteCallback
        end
        return
    end

    -- Callers of this entry point explicitly want fresh data (login
    -- prewarm, /lcviewer rebuild, moderation purges), so force a rebuild
    -- past the built-guard in UpdateAllDiscoveriesCacheSync.
    Cache.discoveriesBuilt = false
    Cache.lastFilterState  = nil
    Cache.filteredResults  = {}

    self:UpdateAllDiscoveriesCacheSync(onCompleteCallback)
end

function Viewer:UpdateAllDiscoveriesCacheSync(onCompleteCallback)
    local pTime = L.ProfileStart and L:ProfileStart() 

    if Cache.discoveriesBuilt or Cache.discoveriesBuilding then
        VDebug("UpdateAllDiscoveriesCacheSync: skipped (built=" .. tostring(Cache.discoveriesBuilt) .. ", building=" .. tostring(Cache.discoveriesBuilding) .. ")")
        if pTime then L:ProfileStop("Viewer:UpdateAllDiscoveries", pTime) end
        return
    end

    Cache.discoveriesBuilding = true
    self.hasUncachedData = false
    Cache.uniqueValuesValid   = false
    Cache.duplicateItems      = {}
    wipe(Cache.discoveriesByGuid)

    if self.window and self.window:IsShown() then
        self:UpdatePagination()
        self:UpdateReloadHint()
    end

    wipe(self._cacheBuildQueue)
    self.scanProgressCallback = onCompleteCallback
    
    local discoveries = L:GetDiscoveriesDB()
    local vendors = L:GetVendorsDB()
    
    for guid, discovery in pairs(discoveries or {}) do
        table.insert(self._cacheBuildQueue, { guid = guid, d = discovery, isVendor = false })
    end

    -- Discoveries lists real pins only. Worldforged catalog gaps are no longer
    -- injected as synthetic "undiscovered" rows (that filled empty installs with
    -- ~1800 placeholders and made Undiscovered: Hidden look like a blank bug).

    for guid, discovery in pairs(vendors or {}) do
        table.insert(self._cacheBuildQueue, { guid = guid, d = discovery, isVendor = true })
    end
    
    self._cacheBuildIndex = 1
    
    local useAsync = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.asyncLoading
    if useAsync == nil then useAsync = true end

    if useAsync then
        self:ProcessCacheBuildChunk()
    else
        
        self:ProcessCacheBuildChunk(999999) 
    end
    
    if pTime then L:ProfileStop("Viewer:UpdateAllDiscoveries", pTime) end
end

function Viewer:ProcessCacheBuildChunk(budgetOverride)
    if not Cache.discoveriesBuilding then return end
    
    local budget = budgetOverride or 8.0 
    local startMs = debugprofilestop()
    
    local outIndex = self._cacheBuildIndex
    local queue = self._cacheBuildQueue
    local total = #queue
    local processedThisFrame = 0
    local queueCursor = self._cacheQueueCursor or 1
    
    while queueCursor <= total do
        local entry = queue[queueCursor]
        local guid = entry.guid
        local discovery = entry.d

        local row = Cache.discoveries[outIndex]
        if not row then
            row = {}
            Cache.discoveries[outIndex] = row
        end

        local itemSuccessfullyLoaded = FillDiscoveryRow(row, guid, discovery, {
            isVendor = entry.isVendor,
            isUndiscovered = entry.isUndiscovered,
            allowDBPurge = true,
        })

        if itemSuccessfullyLoaded and discovery.i and not entry.isVendor then
            AdjustDuplicateCount(discovery.i, 1)
        end

        queueCursor = queueCursor + 1
        processedThisFrame = processedThisFrame + 1

        if itemSuccessfullyLoaded then
            outIndex = outIndex + 1
        end

        if debugprofilestop() - startMs >= budget then
            break
        end
    end
    
    self._cacheBuildIndex = outIndex
    self._cacheQueueCursor = queueCursor
    
    if queueCursor <= total then
        
        if self.window and self.window:IsShown() then
            self:UpdatePagination()
        end
        C_Timer.After(0.01, function() Viewer:ProcessCacheBuildChunk(budgetOverride) end)
    else
        
        for i = outIndex, #Cache.discoveries do
            Cache.discoveries[i] = nil
        end

        RebuildDiscoveriesByGuid()

        Cache.discoveriesBuilt = true
        Cache.discoveriesBuilding = false

        wipe(self._cacheBuildQueue)
        self._cacheQueueCursor = nil

        -- Sync count so HasDataChanged does not force another full rebuild.
        do
            local n = 0
            local db = L:GetDiscoveriesDB()
            if db then for _ in pairs(db) do n = n + 1 end end
            Cache.lastDiscoveryCount = n
        end

        -- Rebuild side-effects (purges, GET_ITEM_INFO, delayed Comm "bulk")
        -- must not leave Refresh lit. Hold pending bumps briefly after finish.
        self.pendingUpdatesCount = 0
        self._suppressPendingBumps = true
        if self._suppressPendingTimer and C_Timer.CancelTimer then
            C_Timer.CancelTimer(self._suppressPendingTimer)
            self._suppressPendingTimer = nil
        end
        self._suppressPendingTimer = C_Timer.After(1.5, function()
            Viewer._suppressPendingTimer = nil
            Viewer._suppressPendingBumps = false
            VDebug("pending-bump suppress ended")
        end)
        if self.UpdateRefreshButton then
            self:UpdateRefreshButton()
        end

        -- The build queues item lookups; make sure the (self-cancelling)
        -- cache pump is running to drain them.
        do
            local CoreM = L:GetModule("Core", true)
            if CoreM and CoreM.EnsureCachePump then
                CoreM:EnsureCachePump()
            end
        end
        
        if self.scanProgressCallback then
            self.scanProgressCallback()
            self.scanProgressCallback = nil
        end
        
        if self.window and self.window:IsShown() then
            self:UpdatePagination()
            
            Cache.lastFilterState = nil 
            self:GetFilteredDiscoveries()
            self:UpdateRows()
            self:UpdateFilterButtonStates()
            
            if self._rebuildNeeded then
                self._rebuildNeeded = nil
                if not self._refreshTimer then
                    self._refreshTimer = C_Timer.After(0.3, function()
                        self._refreshTimer = nil
                        if self.window and self.window:IsShown() then
                            self:RefreshData()
                        end
                    end)
                end
            end
        end
    end
end

function Viewer:ProcessScanQueueBatch()
    if not Cache.discoveriesBuilding then return end
    self:ProcessCacheBuildChunk()
end

-- Hoisted filter closures (allocated once). Per-pass flags live in _filterEvalCtx.
local _filterEvalCtx = {
    isCoARealm = false,
    hideBagsOn = false,
    isVendorView = false,
}

local filterPredicates = {
    mainFilter = function(data)
        local Constants = L:GetModule("Constants", true)
        -- Vendors are exempt from the forbidden-zone check: special
        -- vendors legitimately stand inside capital cities.
        if not data.isUndiscovered and not data.isVendor and Constants and Constants.IsForbiddenZone and Constants:IsForbiddenZone(data.discovery.c, data.discovery.z, data.discovery.fp) then
            return false
        end

        -- CoA realms removed Librams/Idols/Totems entirely: hide any
        -- relic row (discovered or undiscovered) as soon as its equip
        -- slot is known from item data.
        if _filterEvalCtx.isCoARealm and data.equipLoc == "INVTYPE_RELIC" then
            return false
        end

        -- "Hide Bags" (map filter) now also applies to the list.
        if _filterEvalCtx.hideBagsOn and data.equipLoc == "INVTYPE_BAG" then
            return false
        end

        if Viewer.currentFilter == "eq" then
            return not data.isMystic and not data.isVendor
        elseif Viewer.currentFilter == "ms" then
            return data.isMystic and not data.isVendor
        elseif Viewer.currentFilter == "bmv" then
            return data.isVendor
        end
        return false
    end,

    searchFilter = function(data)
        -- Live free-text search removed; chips (deepSearchFilters) handle search.
        return true
    end,

    -- Search chips: name OR zone OR tooltip; rows AND together.
    deepSearchFilter = function(data)
        return Viewer:MatchesDeepFilterOnRow(data)
    end,

    columnFilters = {
        eq = {
            slot = function(data)
                if size(Viewer.columnFilters.eq.slot) == 0 then return true end
                local slotValue = data.equipLoc and _G[data.equipLoc] or ""
                return Viewer.columnFilters.eq.slot[slotValue] ~= nil
            end,
            type = function(data)
                return DiscoveryMatchesTypeFilter(data, Viewer.columnFilters.eq.type)
            end,
        },
        ms = {
            class = function(data)
                if size(Viewer.columnFilters.ms.class) == 0 then return true end
                local classValue = ""
                if data.cl and data.cl ~= "cl" then
                    local classToken = CLASS_ABBREVIATIONS_REVERSE[data.cl]
                    if classToken then
                        classValue = _G.LOCALIZED_CLASS_NAMES_MALE[classToken] or _G.LOCALIZED_CLASS_NAMES_FEMALE[classToken] or ""
                    end
                end
                if classValue == "" then classValue = data.characterClass or "" end
                return Viewer.columnFilters.ms.class[classValue] ~= nil
            end,
        },
        vendorType = function(data)
            if size(Viewer.columnFilters.vendorType) == 0 then return true end
            local typeMap = { ["BM"] = "Blackmarket", ["MS"] = "Mystic Enchants" }
            local vType = data.vendorType or (data.discovery and data.discovery.vendorType)
            if not vType and data.discovery and data.discovery.g then
                if data.discovery.g:find("BM-", 1, true) then vType = "BM"
                elseif data.discovery.g:find("MS-", 1, true) then vType = "MS" end
            end
            local typeName = typeMap[vType] or vType or "Unknown"
            return Viewer.columnFilters.vendorType[typeName] ~= nil
        end,
        zone = function(data)
            if size(Viewer.columnFilters.zone) == 0 then return true end
            local zoneValue = GetLocalizedZoneName(data.discovery)
            return Viewer.columnFilters.zone[zoneValue] ~= nil
        end,
        source = function(data)
            if _filterEvalCtx.isVendorView then return true end
            if size(Viewer.columnFilters.source) == 0 then return true end
            local source     = data.discovery.src or "unknown"
            local sourceValue= SOURCE_NAMES[source] or source
            return Viewer.columnFilters.source[sourceValue] ~= nil
        end,
        quality = function(data)
            if _filterEvalCtx.isVendorView then return true end
            if size(Viewer.columnFilters.quality) == 0 then return true end
            local _, _, quality = GetItemInfoSafe(data.discovery.il, data.discovery.i)
            if not quality then
                return Viewer.columnFilters.quality["Unknown"] ~= nil
            end
            local qualityValue = QUALITY_NAMES[quality] or ("Quality " .. tostring(quality))
            return Viewer.columnFilters.quality[qualityValue] ~= nil
        end,
        looted = function(data)
            if _filterEvalCtx.isVendorView then return true end
            if size(Viewer.columnFilters.looted) == 0 then return true end
            local lootedValue = Viewer:IsLootedByChar(data.guid) and "Looted" or "Not Looted"
            return Viewer.columnFilters.looted[lootedValue] ~= nil
        end,
        duplicates = function(data)
            if _filterEvalCtx.isVendorView then return true end
            if not Viewer.columnFilters.duplicates then return true end
            return Cache.duplicateItems[data.discovery.i] and Cache.duplicateItems[data.discovery.i] > 1
        end,
    },
}

function Viewer:GetFilteredDiscoveries()
    local pTime = L.ProfileStart and L:ProfileStart() 

    if Cache.discoveriesBuilding then 
        if pTime then L:ProfileStop("Viewer:GetFilteredDiscoveries", pTime) end
        return {} 
    end

    if not Cache.discoveriesBuilt then
        self:UpdateAllDiscoveriesCacheSync()
    end

    if not Cache.discoveriesBuilt then 
        if pTime then L:ProfileStop("Viewer:GetFilteredDiscoveries", pTime) end
        return {} 
    end

    local filterState = self:GetFilterStateHash()

    if Cache.lastFilterState ~= filterState then
        self:ScheduleMapViewerFilterNotify()
        if self.SchedulePersistLiveFilters then self:SchedulePersistLiveFilters() end
    end

    -- Empty is a valid cached result (tight presets can match nothing).
    if Cache.lastFilterState == filterState then
        if pTime then L:ProfileStop("Viewer:GetFilteredDiscoveries", pTime) end
        return Cache.filteredResults
    end

    local currentFiltered = self._reusableCurrentFiltered
    wipe(currentFiltered)
    
    local discoveriesToFilter = Cache.discoveries
    local totalToFilter     = #discoveriesToFilter
    
    local context = GetCascadedFilterContext(nil)
    local isVendorView = (self.currentFilter == "bmv")

    local CoreMod = L:GetModule("Core", true)
    _filterEvalCtx.isVendorView = isVendorView
    _filterEvalCtx.isCoARealm = CoreMod and CoreMod.IsConfirmedCoARealm and CoreMod:IsConfirmedCoARealm()
    _filterEvalCtx.hideBagsOn = L.db and L.db.char and L.db.char.mapFilters and L.db.char.mapFilters.hideBags

    for i = 1, totalToFilter do
        local data = discoveriesToFilter[i]
        if data then
            local passed = true
            
            if not filterPredicates.mainFilter(data) then passed = false end
            if passed and not filterPredicates.searchFilter(data) then passed = false end
            -- Search chips (name/zone/tooltip) — includes vendors (name match).
            if passed and not filterPredicates.deepSearchFilter(data) then passed = false end

            if passed and not data.isVendor and not data.isMystic then
                if self.minReqLevel and (data.minLevel or 0) < self.minReqLevel then passed = false end
                if self.maxReqLevel and (data.minLevel or 0) > self.maxReqLevel then passed = false end
            end

            if passed and not data.isVendor then
                if not filterPredicates.columnFilters.source(data)   then passed = false end
                if passed and not filterPredicates.columnFilters.quality(data)  then passed = false end
                if passed and not filterPredicates.columnFilters.looted(data)   then passed = false end
            end
          
            if passed and self.currentFilter == "eq" then
                local filterGroup = filterPredicates.columnFilters[self.currentFilter]
                if filterGroup then
                    if not filterGroup.slot(data) then passed = false end
                    if passed and not filterGroup.type(data) then passed = false end
                end
            elseif passed and self.currentFilter == "ms" then
                if not filterPredicates.columnFilters.ms.class(data) then passed = false end
            elseif passed and self.currentFilter == "bmv" then
                if not filterPredicates.columnFilters.vendorType(data) then passed = false end
            end
      
            if passed and context.activeFilters.class then
                if context.currentFilter == "eq" then
                    local Constants = L:GetModule("Constants", true)
                    if Constants and Constants.CLASS_PROFICIENCIES then
                        local subTypeID = data.ist
                        local typeID = data.it
                        if subTypeID and typeID and subTypeID > 0 and typeID > 0 then
                            local canUse = false
                            for classFilterName, _ in pairs(context.activeFilters.class) do
                                 local classToken = nil
                                 if Constants and Constants.GetClassTokenFromLocalizedName then
                                     local foundToken = Constants:GetClassTokenFromLocalizedName(classFilterName)
                                     if foundToken ~= classFilterName then classToken = foundToken end
                                 end
                                 if not classToken and _G.LOCALIZED_CLASS_NAMES_MALE then
                                     for token, locName in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
                                         if locName == classFilterName then classToken = token; break end
                                     end
                                 end
                                 if not classToken and _G.LOCALIZED_CLASS_NAMES_FEMALE then
                                     for token, locName in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
                                         if locName == classFilterName then classToken = token; break end
                                     end
                                 end
                                 if not classToken then classToken = string.upper(classFilterName) end
                                 
                                 local profs = Constants.CLASS_PROFICIENCIES[classToken]
                                 if profs then
                                     local list = nil
                                     if typeID == Constants.ITEM_TYPE_TO_ID["Armor"] then list = profs.armor
                                     elseif typeID == Constants.ITEM_TYPE_TO_ID["Weapon"] then list = profs.weapons end
                                     
                                     if list then
                                         for _, allowedID in ipairs(list) do
                                             if subTypeID == allowedID then canUse = true; break end
                                         end
                                     else
                                         canUse = true 
                                     end
                                 end
                                 if canUse then break end
                            end
                            if not canUse then passed = false end
                        else
                            passed = false
                        end
                    end
                end
            end

            if passed and not filterPredicates.columnFilters.zone(data) then passed = false end

            if passed and Viewer.lootedFilterState ~= nil and not isVendorView then
                local isLooted = Viewer:IsLootedByChar(data.guid)
                if Viewer.lootedFilterState == true and not isLooted then passed = false end
                if Viewer.lootedFilterState == false and isLooted then passed = false end
            end

            if passed and Viewer.fadeFilterState and not isVendorView then
                if not PassesFadeFilter(data.discovery) then passed = false end
            end

            if passed and Viewer.favoritesFilterState == true and not isVendorView then
                if not (data.discovery.i and L:GetFavoritesDB()[data.discovery.i]) then passed = false end
            end

            if passed and Viewer.collectedMEFilterState ~= nil and not isVendorView then
                local Constants = L:GetModule("Constants", true)
                local isME = Constants and data.discovery.dt == Constants.DISCOVERY_TYPE.MYSTIC_SCROLL
                if isME and data.discovery.i and data.discovery.i > 0 then
                    local isCollectedME = L:IsMysticEnchantCollected(data.discovery.i)
                    if Viewer.collectedMEFilterState == true and not isCollectedME then passed = false end
                    if Viewer.collectedMEFilterState == false and isCollectedME then passed = false end
                elseif not isME then
                    if Viewer.collectedMEFilterState == true then passed = false end
                end
            end

            if passed and not filterPredicates.columnFilters.duplicates(data) then passed = false end

            if passed then
                table.insert(currentFiltered, data)
            end
        end
    end

    table.sort(currentFiltered, function(a, b)
        if not a or not b then return false end
        if not a.discovery or not b.discovery then return false end

        if self.lastSeenSortState == "new" then
            local la = tonumber(a.discovery.ls) or 0
            local lb = tonumber(b.discovery.ls) or 0
            if la ~= lb then return la > lb end
        elseif self.lastSeenSortState == "old" then
            local la = tonumber(a.discovery.ls) or 0
            local lb = tonumber(b.discovery.ls) or 0
            if la ~= lb then return la < lb end
        end

        local a_val, b_val
        if self.sortColumn == "name" or self.sortColumn == "vendorName" then
            a_val = a.sortName; b_val = b.sortName
        elseif self.sortColumn == "zone" then
            a_val = a.zoneNameStr; b_val = b.zoneNameStr
        elseif self.sortColumn == "slot" then
            a_val = a.sortSlot; b_val = b.sortSlot
        elseif self.sortColumn == "type" then
            a_val = a.sortType; b_val = b.sortType
        elseif self.sortColumn == "class" then
            a_val = a.sortClass; b_val = b.sortClass
        elseif self.sortColumn == "foundBy" then
            a_val = a.discovery.fp or ""; b_val = b.discovery.fp or ""
        elseif self.sortColumn == "favorite" then
            local a_fav = (a.discovery and a.discovery.i and L:GetFavoritesDB()[a.discovery.i]) and 1 or 0
            local b_fav = (b.discovery and b.discovery.i and L:GetFavoritesDB()[b.discovery.i]) and 1 or 0
            if a_fav == b_fav then
                if self.sortAscending then return a.sortName < b.sortName else return a.sortName > b.sortName end
            end
            a_val = a_fav; b_val = b_fav
        elseif self.sortColumn == "level" then
            a_val = a.minLevel or 0; b_val = b.minLevel or 0
        elseif self.sortColumn == "vendorType" then
            -- FIXED: the Vendors tab defaults to sortColumn "vendorType",
            -- but no comparator branch existed for it (nor for price /
            -- continent), so all three silently fell through to GUID
            -- ordering while the header showed an active sort arrow.
            a_val = a.sortType or ""; b_val = b.sortType or ""
            if a_val == b_val then a_val = a.sortName or ""; b_val = b.sortName or "" end
        elseif self.sortColumn == "price" then
            -- Vendor list rows carry no aggregate price; sort by name so
            -- the header behaves predictably instead of GUID-ordering.
            a_val = a.sortName or ""; b_val = b.sortName or ""
        elseif self.sortColumn == "continent" then
            a_val = tostring(a.discovery and a.discovery.c or 0) .. "|" .. (a.zoneNameStr or "")
            b_val = tostring(b.discovery and b.discovery.c or 0) .. "|" .. (b.zoneNameStr or "")
        else
            a_val = a.guid or ""; b_val = b.guid or ""
        end

        if self.sortAscending then return a_val < b_val else return a_val > b_val end
    end)

    local finalFiltered = self._reusableFinalFiltered
    wipe(finalFiltered)
    
    for _, data in ipairs(currentFiltered) do
        table.insert(finalFiltered, data)
        if self.inlineVendorView and Viewer.expandedVendors and Viewer.expandedVendors[data.guid] and data.discovery and data.discovery.vendorItems then
            for _, item in ipairs(data.discovery.vendorItems) do
                table.insert(finalFiltered, {
                    isVendorItemRow = true,
                    item = item,
                    parentVendor = data,
                })
            end
        end
    end
    
    Cache.filteredResults = finalFiltered
    Cache.lastFilterState = filterState

    if pTime then L:ProfileStop("Viewer:GetFilteredDiscoveries", pTime) end 
    return Cache.filteredResults
end

local _fpParts = {}
local _dsfScratch = {}

local function BuildFilterHashFingerprint(self)
    local dsf = self.deepSearchFilters
    local hideBags = L.db and L.db.char and L.db.char.mapFilters and L.db.char.mapFilters.hideBags
    local wfPhase = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.worldforgedPhase or 0
    wipe(_fpParts)
    _fpParts[1] = self.currentFilter or ""
    _fpParts[2] = self.sortColumn or ""
    _fpParts[3] = tostring(self.sortAscending)
    _fpParts[4] = tostring(self.minReqLevel)
    _fpParts[5] = tostring(self.maxReqLevel)
    _fpParts[6] = tostring(self.lastSeenSortState or "off")
    _fpParts[7] = tostring(self.lootedFilterState)
    _fpParts[8] = tostring(self.collectedMEFilterState)
    _fpParts[9] = tostring(self.favoritesFilterState)
    _fpParts[10] = (L.db and L.db.profile and L.db.profile.perCharacterFavorites) and "c" or "p"
    _fpParts[11] = tostring(dsf and #dsf or 0)
    _fpParts[12] = (self.columnFilters and self.columnFilters.duplicates) and "1" or "0"
    _fpParts[13] = tostring(wfPhase)
    _fpParts[14] = hideBags and "1" or "0"
    _fpParts[15] = tostring(self.fadeFilterState)
    local n = 15
    if dsf then
        for i = 1, #dsf do
            n = n + 1
            _fpParts[n] = dsf[i]
        end
    end
    return _tconcat(_fpParts, "|")
end

function Viewer:GetFilterStateHash()
    local fp = BuildFilterHashFingerprint(self)
    if not _filterHashDirty and Cache.lastFilterState ~= nil and _cachedFilterHash and fp == _filterHashFingerprint then
        return _cachedFilterHash
    end

    wipe(_hashParts)
    _hashParts[1] = self.currentFilter
    _hashParts[2] = self.sortColumn
    _hashParts[3] = tostring(self.sortAscending)
    _hashParts[4] = tostring(self.minReqLevel)
    _hashParts[5] = tostring(self.maxReqLevel)
    _hashParts[6] = tostring(self.lastSeenSortState or "off")

    -- columnFilters mixes two shapes: eq/ms are double-nested
    -- (eq.slot = {value=true}), while zone/source/quality/looted/vendorType
    -- are flat maps (zone = {value=true}). The old loop assumed everything
    -- was double-nested, so the flat filters NEVER contributed to the hash
    -- and stale cached results could be served after changing them.
    wipe(_filterEntries)
    for filterType, filters in pairs(self.columnFilters) do
        if FLAT_FILTER_KEYS[filterType] then
            if type(filters) == "table" and size(filters) > 0 then
                local sortedValues = keys(filters)
                _tsort(sortedValues)
                _tinsert(_filterEntries, concatStrings(filterType, ":", _tconcat(sortedValues, ",")))
            end
        elseif type(filters) == "table" then
            for column, values in pairs(filters) do
                if type(values) == "table" and size(values) > 0 then
                    local sortedValues = keys(values)
                    _tsort(sortedValues)
                    _tinsert(_filterEntries, concatStrings(filterType, ":", column, ":", _tconcat(sortedValues, ",")))
                end
            end
        elseif filterType == "duplicates" and filters then
            _tinsert(_filterEntries, "duplicates:true")
        end
    end
    
    if self.lootedFilterState ~= nil then
        _tinsert(_filterEntries, "looted:" .. tostring(self.lootedFilterState))
    end
    if self.fadeFilterState then
        _tinsert(_filterEntries, "fade:" .. tostring(self.fadeFilterState))
    end
    if self.collectedMEFilterState ~= nil then
        _tinsert(_filterEntries, "collectedME:" .. tostring(self.collectedMEFilterState))
    end
    if self.favoritesFilterState == true then
        _tinsert(_filterEntries, "favorites:true")
    end
    if L.db and L.db.profile and L.db.profile.perCharacterFavorites then
        _tinsert(_filterEntries, "favoritesScope:char")
    else
        _tinsert(_filterEntries, "favoritesScope:profile")
    end
    if self.deepSearchFilters and #self.deepSearchFilters > 0 then
        -- Order among rows doesn't change the result set (all AND), so sort for
        -- a stable cache key.
        wipe(_dsfScratch)
        for i = 1, #self.deepSearchFilters do _dsfScratch[i] = string.lower(self.deepSearchFilters[i]) end
        _tsort(_dsfScratch)
        _tinsert(_filterEntries, concatStrings("deepx:", _tconcat(_dsfScratch, "|")))
    end
    
    -- Belt-and-suspenders: the phase menu already force-clears the caches,
    -- but include the phase in the hash so no future phase-changing code
    -- path can ever be served a stale filtered list.
    local wfPhase = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.worldforgedPhase or 0
    _tinsert(_filterEntries, "wfphase:" .. tostring(wfPhase))

    if L.db and L.db.char and L.db.char.mapFilters and L.db.char.mapFilters.hideBags then
        _tinsert(_filterEntries, "hidebags:1")
    end

    local hash = _tconcat(_hashParts, "|")
    if #_filterEntries > 0 then
        hash = concatStrings(hash, "|", _tconcat(_filterEntries, "|"))
    end

    _cachedFilterHash = hash
    _filterHashFingerprint = fp
    _filterHashDirty = false
    return hash
end

function Viewer:GetMainScrollHeight()
    if not self.window then return 450 end
    -- Chrome: title + tabs + filter row + search + headers + pagination (~232)
    local base = self.window:GetHeight() - 232
    if self.currentFilter == "bmv" and not self.inlineVendorView then
        return base * (self.splitRatio or 0.64)
    end
    return base
end

function Viewer:UpdateLayout()
    if not self.window then return end
    local width = self.window:GetWidth()
    local height = self.window:GetHeight()
    local mainHeight = self:GetMainScrollHeight()
    
    if self.scrollFrame then 
        self.scrollFrame:SetSize(width - 60, mainHeight) 
    end
    
    if self.currentFilter == "bmv" and not self.inlineVendorView then
        self:EnsureVendorInventoryPanel()
        if self.vendorInventoryFrame then
            local invHeight = (height - 232) * (1 - self.splitRatio) - 10
            self.vendorInventoryFrame:SetSize(width - 60, invHeight)
            self.vendorInventoryFrame:Show()
            self:UpdateVendorInventoryScroll()
        end
        
        if self.splitterBar then
            self.splitterBar:SetWidth(width - 60)
            self.splitterBar:ClearAllPoints()
            
            self.splitterBar:SetPoint("TOPLEFT", self.scrollFrame, "BOTTOMLEFT", 0, 4)
            self.splitterBar:Show()
        end
    else
        if self.vendorInventoryFrame then
            self.vendorInventoryFrame:Hide()
        end
        if self.splitterBar then
            self.splitterBar:Hide()
        end
    end
end

function Viewer:GetEffectiveItemsPerPage()
    local visibleRows = 0
    if self.window then
        visibleRows = math.ceil(self:GetMainScrollHeight() / ROW_HEIGHT)
    end
    return math.max(self.itemsPerPage, visibleRows)
end

function Viewer:GetPaginatedDiscoveries()
    local allDiscoveries = self:GetFilteredDiscoveries()
    self.totalItems = #allDiscoveries

    local effectiveItemsPerPage = self:GetEffectiveItemsPerPage()

    -- FIXED: clamp the current page whenever the result set shrinks
    -- (refresh with new data, unfavoriting the last item on the last page,
    -- narrowing filters through code paths that don't reset the page).
    -- Without this the grid rendered a blank out-of-range page.
    local totalPages = math.max(1, math.ceil(self.totalItems / effectiveItemsPerPage))
    if (self.currentPage or 1) > totalPages then
        self.currentPage = totalPages
    end
    if (self.currentPage or 1) < 1 then
        self.currentPage = 1
    end

    local startIndex = (self.currentPage - 1) * effectiveItemsPerPage + 1
    local endIndex = math.min(startIndex + effectiveItemsPerPage - 1, self.totalItems)

    local pageDiscoveries = {}
    
    pageDiscoveries[math.min(effectiveItemsPerPage, self.totalItems)] = nil

    for i = startIndex, endIndex do
        if allDiscoveries[i] then
            _tinsert(pageDiscoveries, allDiscoveries[i])
        end
    end

    return pageDiscoveries
end

function Viewer:GetTotalPages()
    return math.max(1, math.ceil(self.totalItems / self:GetEffectiveItemsPerPage()))
end

local function GetColorForDiscovery(discovery, itemID)
    local _, _, q = GetItemInfoSafe(discovery.il, itemID)
    if not q and discovery.q then
        q = tonumber(discovery.q)
    end
    q = q or 1 
    return GetQualityColor(q)
end

function Viewer:HasActiveFilters()    
    if self.deepSearchFilters and #self.deepSearchFilters > 0 then return true end
    if self.minReqLevel or self.maxReqLevel then return true end
    if size(self.columnFilters.zone) > 0 then return true end
 
    if self.columnFilters.eq and (size(self.columnFilters.eq.slot) > 0 or size(self.columnFilters.eq.type) > 0 or size(self.columnFilters.eq.class) > 0) then
        return true
    end

    if self.columnFilters.ms and size(self.columnFilters.ms.class) > 0 then
        return true
    end

    if size(self.columnFilters.source) > 0 then return true end
    if size(self.columnFilters.quality) > 0 then return true end
    if size(self.columnFilters.vendorType) > 0 then return true end
    if self.lootedFilterState ~= nil or size(self.columnFilters.looted) > 0 then return true end
    if self.collectedMEFilterState ~= nil then return true end
    if self.columnFilters.duplicates then return true end
    
    if self.lastSeenSortState and self.lastSeenSortState ~= "off" then return true end
    if self.favoritesFilterState == true then return true end
    if self.fadeFilterState then return true end

    return false
end

function Viewer:UpdateClearAllButton()
    if not self.clearAllBtn or not self.actionsLabel then return end

    if self:HasActiveFilters() then
        self.clearAllBtn:Show()
        self.clearAllBtn:SetText("Clear")
    else
        self.clearAllBtn:Hide()
        self.actionsLabel:Show()
    end
end

function Viewer:BuildTypeFilterEasyMenu()
    local typeFilters = Viewer.columnFilters.eq.type

    local function afterTypeChange()
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end

    local function rebuildMenu()
        afterTypeChange()
        if EasyMenu and Viewer.typeFilterBtn then
            HideDropDownMenu(1)
            EasyMenu(Viewer:BuildTypeFilterEasyMenu(), TypeFilterMenuHost, Viewer.typeFilterBtn, 0, 0, "MENU", 2)
        end
    end

    local function toggleSubtype(name)
        if typeFilters[name] then
            typeFilters[name] = nil
        else
            typeFilters[name] = true
        end
        afterTypeChange()
    end

    local function buildSubtypeSubmenu(title, list)
        local sub = {
            { text = title, isTitle = true, notCheckable = true },
            {
                text = "Select All",
                notCheckable = true,
                func = function()
                    for _, name in ipairs(list) do
                        typeFilters[name] = true
                    end
                    rebuildMenu()
                end,
            },
            {
                text = "Clear All",
                notCheckable = true,
                func = function()
                    for _, name in ipairs(list) do
                        typeFilters[name] = nil
                    end
                    rebuildMenu()
                end,
            },
        }
        for _, name in ipairs(list) do
            _tinsert(sub, {
                text = name,
                checked = typeFilters[name] and true or false,
                keepShownOnClick = true,
                isNotRadio = true,
                func = function() toggleSubtype(name) end,
            })
        end
        return sub
    end

    return {
        {
            text = "Clear Type Filters",
            notCheckable = true,
            func = function()
                wipe(typeFilters)
                afterTypeChange()
            end,
        },
        {
            text = "Armor",
            hasArrow = true,
            notCheckable = true,
            menuList = buildSubtypeSubmenu("Armor", TYPE_FILTER_ARMOR),
        },
        {
            text = "Weapon",
            hasArrow = true,
            notCheckable = true,
            menuList = buildSubtypeSubmenu("Weapon", TYPE_FILTER_WEAPON),
        },
        {
            text = "Misc",
            hasArrow = true,
            notCheckable = true,
            menuList = buildSubtypeSubmenu("Misc", TYPE_FILTER_MISC),
        },
    }
end

function Viewer:ShowTypeFilterMenu(anchor)
    if not EasyMenu or not anchor then return end

    local dropdownList = _G["DropDownList1"]
    if Viewer.currentFilterAnchor == anchor and dropdownList and dropdownList:IsShown() then
        HideDropDownMenu(1)
        Viewer.currentFilterAnchor = nil
        return
    end
    Viewer.currentFilterAnchor = anchor
    EasyMenu(self:BuildTypeFilterEasyMenu(), TypeFilterMenuHost, anchor, 0, 0, "MENU", 2)
end

local function FindDeepSearchChipIndex(expr)
    if not expr or expr == "" then return nil end
    local filters = Viewer.deepSearchFilters
    if not filters then return nil end
    local lower = string.lower(expr)
    for i = 1, #filters do
        if string.lower(filters[i]) == lower then
            return i
        end
    end
    return nil
end

function Viewer:HasActiveStatFilterChips()
    if type(L.db) == "table" and L.db.profile then
        if type(L.db.profile.deepSearchFilters) ~= "table" then
            L.db.profile.deepSearchFilters = {}
        end
        self.deepSearchFilters = L.db.profile.deepSearchFilters
    end
    local filters = self.deepSearchFilters
    if not filters or #filters == 0 then return false end
    for _, cat in ipairs(STAT_FILTER_CATEGORIES) do
        for _, stat in ipairs(cat.stats) do
            if FindDeepSearchChipIndex(stat.expr) then
                return true
            end
        end
    end
    return false
end

function Viewer:ToggleStatFilterChip(expr)
    if not expr or expr == "" then return end
    if type(L.db) == "table" and L.db.profile then
        if type(L.db.profile.deepSearchFilters) ~= "table" then
            L.db.profile.deepSearchFilters = {}
        end
        self.deepSearchFilters = L.db.profile.deepSearchFilters
    else
        self.deepSearchFilters = self.deepSearchFilters or {}
    end

    local idx = FindDeepSearchChipIndex(expr)
    if idx then
        _tremove(self.deepSearchFilters, idx)
    else
        _tinsert(self.deepSearchFilters, expr)
    end

    self:RebuildDeepCompiled()
    if self.RefreshDeepFilterPanel then self:RefreshDeepFilterPanel() end
    self.currentPage = 1
    Cache.filteredResults = {}
    Cache.lastFilterState = nil
    self:RefreshData()
    self:UpdateClearAllButton()
    self:UpdateFilterButtonStates()
    if self.NotifyMapDeepFilterChanged then self:NotifyMapDeepFilterChanged() end
end

function Viewer:SetStatFilterChipsInList(list, enabled)
    if type(L.db) == "table" and L.db.profile then
        if type(L.db.profile.deepSearchFilters) ~= "table" then
            L.db.profile.deepSearchFilters = {}
        end
        self.deepSearchFilters = L.db.profile.deepSearchFilters
    else
        self.deepSearchFilters = self.deepSearchFilters or {}
    end

    for _, stat in ipairs(list) do
        local idx = FindDeepSearchChipIndex(stat.expr)
        if enabled then
            if not idx then _tinsert(self.deepSearchFilters, stat.expr) end
        else
            if idx then _tremove(self.deepSearchFilters, idx) end
        end
    end

    self:RebuildDeepCompiled()
    if self.RefreshDeepFilterPanel then self:RefreshDeepFilterPanel() end
    self.currentPage = 1
    Cache.filteredResults = {}
    Cache.lastFilterState = nil
    self:RefreshData()
    self:UpdateClearAllButton()
    self:UpdateFilterButtonStates()
    if self.NotifyMapDeepFilterChanged then self:NotifyMapDeepFilterChanged() end
end

function Viewer:BuildStatsFilterEasyMenu()
    local function rebuildMenu()
        if EasyMenu and Viewer.statsFilterBtn then
            HideDropDownMenu(1)
            EasyMenu(Viewer:BuildStatsFilterEasyMenu(), StatsFilterMenuHost, Viewer.statsFilterBtn, 0, 0, "MENU", 2)
        end
    end

    local function buildStatSubmenu(title, list)
        local sub = {
            { text = title, isTitle = true, notCheckable = true },
            {
                text = "Select All",
                notCheckable = true,
                func = function()
                    Viewer:SetStatFilterChipsInList(list, true)
                    rebuildMenu()
                end,
            },
            {
                text = "Clear All",
                notCheckable = true,
                func = function()
                    Viewer:SetStatFilterChipsInList(list, false)
                    rebuildMenu()
                end,
            },
        }
        for _, stat in ipairs(list) do
            _tinsert(sub, {
                text = stat.label,
                checked = FindDeepSearchChipIndex(stat.expr) ~= nil,
                keepShownOnClick = true,
                isNotRadio = true,
                func = function()
                    Viewer:ToggleStatFilterChip(stat.expr)
                    rebuildMenu()
                end,
            })
        end
        return sub
    end

    local menu = {
        {
            text = "Clear Stats Filters",
            notCheckable = true,
            func = function()
                if type(L.db) == "table" and L.db.profile then
                    if type(L.db.profile.deepSearchFilters) ~= "table" then
                        L.db.profile.deepSearchFilters = {}
                    end
                    Viewer.deepSearchFilters = L.db.profile.deepSearchFilters
                else
                    Viewer.deepSearchFilters = Viewer.deepSearchFilters or {}
                end
                for _, cat in ipairs(STAT_FILTER_CATEGORIES) do
                    for _, stat in ipairs(cat.stats) do
                        local idx = FindDeepSearchChipIndex(stat.expr)
                        while idx do
                            _tremove(Viewer.deepSearchFilters, idx)
                            idx = FindDeepSearchChipIndex(stat.expr)
                        end
                    end
                end
                Viewer:RebuildDeepCompiled()
                if Viewer.RefreshDeepFilterPanel then Viewer:RefreshDeepFilterPanel() end
                Viewer.currentPage = 1
                Cache.filteredResults = {}
                Cache.lastFilterState = nil
                Viewer:RefreshData()
                Viewer:UpdateClearAllButton()
                Viewer:UpdateFilterButtonStates()
                if Viewer.NotifyMapDeepFilterChanged then Viewer:NotifyMapDeepFilterChanged() end
            end,
        },
    }

    for _, cat in ipairs(STAT_FILTER_CATEGORIES) do
        _tinsert(menu, {
            text = cat.name,
            hasArrow = true,
            notCheckable = true,
            menuList = buildStatSubmenu(cat.name, cat.stats),
        })
    end
    return menu
end

function Viewer:ShowStatsFilterMenu(anchor)
    if not EasyMenu or not anchor then return end

    if type(L.db) == "table" and L.db.profile then
        if type(L.db.profile.deepSearchFilters) ~= "table" then
            L.db.profile.deepSearchFilters = {}
        end
        self.deepSearchFilters = L.db.profile.deepSearchFilters
    else
        self.deepSearchFilters = self.deepSearchFilters or {}
    end

    local dropdownList = _G["DropDownList1"]
    if Viewer.currentFilterAnchor == anchor and dropdownList and dropdownList:IsShown() then
        HideDropDownMenu(1)
        Viewer.currentFilterAnchor = nil
        return
    end
    Viewer.currentFilterAnchor = anchor
    EasyMenu(self:BuildStatsFilterEasyMenu(), StatsFilterMenuHost, anchor, 0, 0, "MENU", 2)
end

function Viewer:EnsureFilterPresetsTable()
    if type(L.db) ~= "table" or not L.db.profile then
        return {}
    end
    if type(L.db.profile.filterPresets) ~= "table" then
        L.db.profile.filterPresets = {}
    end
    return L.db.profile.filterPresets
end

function Viewer:CountFilterPresets()
    local presets = self:EnsureFilterPresetsTable()
    local n = 0
    for _ in pairs(presets) do n = n + 1 end
    return n
end

function Viewer:GetSortedFilterPresetNames()
    local presets = self:EnsureFilterPresetsTable()
    local names = {}
    for name in pairs(presets) do
        _tinsert(names, name)
    end
    _tsort(names)
    return names
end

function Viewer:CaptureFilterPresetSnapshot()
    self:EnsureDeepFiltersLoaded()
    local chips = {}
    if self.deepSearchFilters then
        for i = 1, #self.deepSearchFilters do
            chips[i] = self.deepSearchFilters[i]
        end
    end
    local minReq = self.minReqLevel
    local maxReq = self.maxReqLevel
    if self.minReqLevelBox then
        minReq = tonumber(self.minReqLevelBox:GetText())
    end
    if self.maxReqLevelBox then
        maxReq = tonumber(self.maxReqLevelBox:GetText())
    end
    return {
        currentFilter = self.currentFilter or "eq",
        columnFilters = deepCopy(self.columnFilters),
        deepSearchFilters = chips,
        lootedFilterState = self.lootedFilterState,
        favoritesFilterState = self.favoritesFilterState,
        collectedMEFilterState = self.collectedMEFilterState,
        lastSeenSortState = self.lastSeenSortState or "off",
        fadeFilterState = self.fadeFilterState,
        minReqLevel = minReq,
        maxReqLevel = maxReq,
    }
end

function Viewer:PersistLiveFilters()
    if self._restoringLiveFilters then return end
    if type(L.db) ~= "table" or not L.db.profile then return end
    L.db.profile.viewerLiveFilters = self:CaptureFilterPresetSnapshot()
end

function Viewer:SchedulePersistLiveFilters()
    if self._restoringLiveFilters then return end
    if self._persistLiveFiltersTimer then return end
    self._persistLiveFiltersTimer = C_Timer.After(0.4, function()
        Viewer._persistLiveFiltersTimer = nil
        Viewer:PersistLiveFilters()
    end)
end

function Viewer:ApplyFilterSnapshot(snap)
    if type(snap) ~= "table" then return false end

    self:EnsureDeepFiltersLoaded()

    if type(snap.columnFilters) == "table" then
        self.columnFilters = deepCopy(snap.columnFilters)
        self.columnFilters.eq = self.columnFilters.eq or { slot = {}, type = {}, class = {} }
        self.columnFilters.eq.slot = self.columnFilters.eq.slot or {}
        self.columnFilters.eq.type = self.columnFilters.eq.type or {}
        self.columnFilters.eq.class = self.columnFilters.eq.class or {}
        self.columnFilters.ms = self.columnFilters.ms or { class = {} }
        self.columnFilters.ms.class = self.columnFilters.ms.class or {}
        self.columnFilters.zone = self.columnFilters.zone or {}
        self.columnFilters.source = self.columnFilters.source or {}
        self.columnFilters.quality = self.columnFilters.quality or {}
        self.columnFilters.looted = self.columnFilters.looted or {}
        self.columnFilters.vendorType = self.columnFilters.vendorType or {}
        if self.columnFilters.duplicates == nil then self.columnFilters.duplicates = false end
    end

    wipe(self.deepSearchFilters)
    if type(snap.deepSearchFilters) == "table" then
        for i = 1, #snap.deepSearchFilters do
            _tinsert(self.deepSearchFilters, snap.deepSearchFilters[i])
        end
    end
    self:RebuildDeepCompiled()
    if self.RefreshDeepFilterPanel then self:RefreshDeepFilterPanel() end

    self.lootedFilterState = snap.lootedFilterState
    self.favoritesFilterState = snap.favoritesFilterState
    self.collectedMEFilterState = snap.collectedMEFilterState
    self.lastSeenSortState = snap.lastSeenSortState or "off"
    self.fadeFilterState = snap.fadeFilterState
    local minReq = tonumber(snap.minReqLevel)
    local maxReq = tonumber(snap.maxReqLevel)
    self._applyingReqLevelPreset = true
    if self.minReqLevelBox then
        self.minReqLevelBox:SetText(minReq and tostring(minReq) or "")
    end
    if self.maxReqLevelBox then
        self.maxReqLevelBox:SetText(maxReq and tostring(maxReq) or "")
    end
    self.minReqLevel = minReq
    self.maxReqLevel = maxReq
    self._applyingReqLevelPreset = nil

    local tab = snap.currentFilter or "eq"
    local CoreMod = L:GetModule("Core", true)
    local isCoA = CoreMod and CoreMod.IsConfirmedCoARealm and CoreMod:IsConfirmedCoARealm()
    if isCoA and tab == "ms" then tab = "eq" end
    self.currentFilter = tab
    self.currentPage = 1
    if tab == "bmv" then
        self.sortColumn = "vendorType"
        self.sortAscending = true
    else
        self.sortColumn = "name"
        self.sortAscending = true
    end
    self:SetSelectedRow(nil)
    if self.vendorInventoryFrame then
        self.vendorInventoryFrame:Hide()
        self.selectedVendorGuid = nil
    end

    InvalidateViewerFilterCache()
    Cache.uniqueValuesContext = {}

    if self.UpdateFilterButtons then self:UpdateFilterButtons() end
    if self.UpdateSortHeaders then self:UpdateSortHeaders() end
    if self.window and self.window:IsShown() then
        self:RefreshData()
    end
    if self.UpdateClearAllButton then self:UpdateClearAllButton() end
    if self.UpdateFilterButtonStates then self:UpdateFilterButtonStates() end
    self:NotifyMapViewerFiltersChanged(true)
    return true
end

function Viewer:RestoreLiveFilters()
    if type(L.db) ~= "table" or not L.db.profile then return false end
    local snap = L.db.profile.viewerLiveFilters
    if type(snap) ~= "table" or type(snap.columnFilters) ~= "table" then return false end
    self._restoringLiveFilters = true
    local ok = self:ApplyFilterSnapshot(snap)
    self._restoringLiveFilters = nil
    return ok
end

function Viewer:SaveFilterPreset(name)
    name = strtrim(tostring(name or ""))
    if name == "" then
        print("|cffff0000LootCollector:|r Preset name cannot be empty.")
        return false
    end
    local presets = self:EnsureFilterPresetsTable()
    if not presets[name] and self:CountFilterPresets() >= MAX_FILTER_PRESETS then
        print(string.format("|cffff0000LootCollector:|r Maximum of %d filter presets reached. Delete one first.", MAX_FILTER_PRESETS))
        return false
    end
    presets[name] = self:CaptureFilterPresetSnapshot()
    self:PersistLiveFilters()
    print(string.format("|cff00ff00LootCollector:|r Saved filter preset '%s'.", name))
    return true
end

function Viewer:DeleteFilterPreset(name)
    local presets = self:EnsureFilterPresetsTable()
    if not presets[name] then return false end
    presets[name] = nil
    print(string.format("|cff00ff00LootCollector:|r Deleted filter preset '%s'.", name))
    return true
end

function Viewer:ApplyFilterPreset(name)
    local presets = self:EnsureFilterPresetsTable()
    local snap = presets[name]
    if type(snap) ~= "table" then
        print(string.format("|cffff0000LootCollector:|r Unknown filter preset '%s'.", tostring(name)))
        return false
    end
    if not self:ApplyFilterSnapshot(snap) then
        return false
    end
    self:PersistLiveFilters()
    print(string.format("|cff00ff00LootCollector:|r Loaded filter preset '%s'.", name))
    return true
end

function Viewer:BuildPresetsFilterEasyMenu()
    local names = self:GetSortedFilterPresetNames()
    local count = #names
    local menu = {
        {
            text = "Save Current As...",
            notCheckable = true,
            func = function()
                -- SaveFilterPreset allows overwrite of an existing name even at the cap.
                StaticPopup_Show("LOOTCOLLECTOR_VIEWER_SAVE_PRESET")
            end,
        },
    }

    if count == 0 then
        _tinsert(menu, {
            text = "No saved presets",
            notCheckable = true,
            disabled = true,
        })
        return menu
    end

    local loadList = {
        { text = "Load Preset", isTitle = true, notCheckable = true },
    }
    local deleteList = {
        { text = "Delete Preset", isTitle = true, notCheckable = true },
    }
    for _, name in ipairs(names) do
        _tinsert(loadList, {
            text = name,
            notCheckable = true,
            func = function()
                Viewer:ApplyFilterPreset(name)
            end,
        })
        _tinsert(deleteList, {
            text = name,
            notCheckable = true,
            func = function()
                StaticPopup_Show("LOOTCOLLECTOR_VIEWER_DELETE_PRESET", name, nil, { name = name })
            end,
        })
    end

    _tinsert(menu, {
        text = "Load",
        hasArrow = true,
        notCheckable = true,
        menuList = loadList,
    })
    _tinsert(menu, {
        text = "Delete",
        hasArrow = true,
        notCheckable = true,
        menuList = deleteList,
    })
    return menu
end

function Viewer:ShowPresetsFilterMenu(anchor)
    if not EasyMenu or not anchor then return end

    local dropdownList = _G["DropDownList1"]
    if Viewer.currentFilterAnchor == anchor and dropdownList and dropdownList:IsShown() then
        HideDropDownMenu(1)
        Viewer.currentFilterAnchor = nil
        return
    end
    Viewer.currentFilterAnchor = anchor
    EasyMenu(self:BuildPresetsFilterEasyMenu(), PresetsFilterMenuHost, anchor, 0, 0, "MENU", 2)
end

function Viewer:UpdateFilterButtonStates()
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not self.sourceFilterBtn or not self.qualityFilterBtn or not self.lootedFilterBtn then
        if pTime then L:ProfileStop("Viewer:UpdateFilterButtonStates", pTime) end
        return 
    end

    local function setButtonTextColor(button, r, g, b)
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetTextColor(r, g, b)
        end
    end

    local sourceActive = size(self.columnFilters.source) > 0
    if sourceActive then
        setButtonTextColor(self.sourceFilterBtn, 1, 0.8, 0.2) 
    else
        setButtonTextColor(self.sourceFilterBtn, 1, 1, 1) 
    end
    self.sourceFilterBtn:SetText("Source")

    local qualityActive = size(self.columnFilters.quality) > 0
    if qualityActive then
        setButtonTextColor(self.qualityFilterBtn, 1, 0.8, 0.2) 
    else
        setButtonTextColor(self.qualityFilterBtn, 1, 1, 1) 
    end
    self.qualityFilterBtn:SetText("Quality")

    if self.statsFilterBtn then
        if self:HasActiveStatFilterChips() then
            setButtonTextColor(self.statsFilterBtn, 1, 0.8, 0.2)
        else
            setButtonTextColor(self.statsFilterBtn, 1, 1, 1)
        end
        self.statsFilterBtn:SetText("Stats")
    end

    if self.vendorTypeFilterBtn then
        local typeActive = size(self.columnFilters.vendorType) > 0
        if typeActive then
            setButtonTextColor(self.vendorTypeFilterBtn, 1, 0.8, 0.2)
        else
            setButtonTextColor(self.vendorTypeFilterBtn, 1, 1, 1)
        end
        self.vendorTypeFilterBtn:SetText("Type")
    end

    if self.favoritesFilterBtn then
        if self.favoritesFilterState == true then
            setButtonTextColor(self.favoritesFilterBtn, 1, 0.8, 0.2) 
        else
            setButtonTextColor(self.favoritesFilterBtn, 1, 1, 1) 
        end
        self.favoritesFilterBtn:SetText("Favorites")
        self.favoritesFilterBtn:Enable()
        self.favoritesFilterBtn:SetAlpha(1.0)
    end

    if self.lootedFilterState == true then
        setButtonTextColor(self.lootedFilterBtn, 1, 0.8, 0.2) 
        self.lootedFilterBtn:SetText("Looted: Yes")
    elseif self.lootedFilterState == false then
        setButtonTextColor(self.lootedFilterBtn, 1, 0.8, 0.2) 
        self.lootedFilterBtn:SetText("Looted: No")
    elseif size(self.columnFilters.looted) > 0 then
        setButtonTextColor(self.lootedFilterBtn, 1, 0.8, 0.2) 
        self.lootedFilterBtn:SetText("Looted [F]")
    else
        setButtonTextColor(self.lootedFilterBtn, 1, 1, 1) 
        self.lootedFilterBtn:SetText("Looted: All")
    end
    
    if self.slotsFilterBtn then
        local slotFilters = self.columnFilters[self.currentFilter] and self.columnFilters[self.currentFilter].slot
        local slotsActive = slotFilters and size(slotFilters) > 0
        if slotsActive then
            setButtonTextColor(self.slotsFilterBtn, 1, 0.8, 0.2)
        else
            setButtonTextColor(self.slotsFilterBtn, 1, 1, 1)
        end
        self.slotsFilterBtn:SetText("Slots")
    end

    if self.typeFilterBtn then
        local typeFilters = self.columnFilters.eq and self.columnFilters.eq.type
        local typeActive = typeFilters and size(typeFilters) > 0
        if typeActive then
            setButtonTextColor(self.typeFilterBtn, 1, 0.8, 0.2)
        else
            setButtonTextColor(self.typeFilterBtn, 1, 1, 1)
        end
        self.typeFilterBtn:SetText("Type")
    end
    
    if self.usableByFilterBtn then
        local classActive = false
        if self.currentFilter == "eq" then
            classActive = self.columnFilters[self.currentFilter] and size(self.columnFilters[self.currentFilter].class) > 0
        elseif self.currentFilter == "ms" then
            classActive = size(self.columnFilters.ms.class) > 0
        end
        
        if classActive then
            setButtonTextColor(self.usableByFilterBtn, 1, 0.8, 0.2)
        else
            setButtonTextColor(self.usableByFilterBtn, 1, 1, 1)
        end
        self.usableByFilterBtn:SetText("Usable By")
    end

    if self.collectedMEFilterBtn then
        if self.collectedMEFilterState == true then
            setButtonTextColor(self.collectedMEFilterBtn, 1, 0.8, 0.2)
            self.collectedMEFilterBtn:SetText("Enchant: Yes")
        elseif self.collectedMEFilterState == false then
            setButtonTextColor(self.collectedMEFilterBtn, 1, 0.8, 0.2)
            self.collectedMEFilterBtn:SetText("Enchant: No")
        else
            setButtonTextColor(self.collectedMEFilterBtn, 1, 1, 1)
            self.collectedMEFilterBtn:SetText("Enchant: All")
        end
    end

    if self.lsFilterBtn then
        if self.lastSeenSortState == "new" then
            setButtonTextColor(self.lsFilterBtn, 1, 0.8, 0.2)
            self.lsFilterBtn:SetText("Date: New")
        elseif self.lastSeenSortState == "old" then
            setButtonTextColor(self.lsFilterBtn, 1, 0.8, 0.2)
            self.lsFilterBtn:SetText("Date: Old")
        else
            setButtonTextColor(self.lsFilterBtn, 1, 1, 1)
            self.lsFilterBtn:SetText("Date: Off")
        end
    end

    if self.fadeFilterBtn then
        if self.fadeFilterState == "hide" then
            setButtonTextColor(self.fadeFilterBtn, 1, 0.8, 0.2)
            self.fadeFilterBtn:SetText("Fade: Hide")
        elseif self.fadeFilterState == "only" then
            setButtonTextColor(self.fadeFilterBtn, 1, 0.8, 0.2)
            self.fadeFilterBtn:SetText("Fade: Only")
        else
            setButtonTextColor(self.fadeFilterBtn, 1, 1, 1)
            self.fadeFilterBtn:SetText("Fade: All")
        end
    end

    if self.duplicatesFilterBtn then
        local duplicatesActive = self.columnFilters.duplicates
        if duplicatesActive then
            setButtonTextColor(self.duplicatesFilterBtn, 1, 0.8, 0.2) 
        else
            setButtonTextColor(self.duplicatesFilterBtn, 1, 1, 1) 
        end
        self.duplicatesFilterBtn:SetText("Duplicates")
    end

    local isBmv = (self.currentFilter == "bmv")
    local isEq = (self.currentFilter == "eq")
    local isMs = (self.currentFilter == "ms")

    local showSlots = isEq
    local showItemType = isEq
    local showVendorType = isBmv
    local showNormalFilters = not isBmv

    local CoreMod = L:GetModule("Core", true)
    -- Enchant is ME-collection; hide only on confirmed CoA (Rexxar/Vol'jin).
    local hideEnchantFilter = CoreMod and CoreMod.IsConfirmedCoARealm and CoreMod:IsConfirmedCoARealm()
    if hideEnchantFilter and Viewer.collectedMEFilterState ~= nil then
        Viewer.collectedMEFilterState = nil
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
    end
    
    local Dev = L:GetModule("DevCommands", true)
    local showDuplicates = showNormalFilters and (Dev ~= nil)

    if self.vendorTypeFilterBtn then self.vendorTypeFilterBtn:SetShown(showVendorType) end
    if self.sourceFilterBtn then self.sourceFilterBtn:SetShown(showNormalFilters) end
    if self.qualityFilterBtn then self.qualityFilterBtn:SetShown(showNormalFilters) end
    if self.statsFilterBtn then self.statsFilterBtn:SetShown(showNormalFilters) end
    if self.favoritesFilterBtn then self.favoritesFilterBtn:SetShown(showNormalFilters) end
    if self.typeFilterBtn then self.typeFilterBtn:SetShown(showItemType) end
    if self.slotsFilterBtn then self.slotsFilterBtn:SetShown(showSlots) end
    if self.usableByFilterBtn then self.usableByFilterBtn:SetShown(showNormalFilters) end
    if self.lootedFilterBtn then self.lootedFilterBtn:SetShown(showNormalFilters) end
    if self.collectedMEFilterBtn then self.collectedMEFilterBtn:SetShown(showNormalFilters and not hideEnchantFilter) end
    if self.lsFilterBtn then self.lsFilterBtn:SetShown(showNormalFilters) end
    if self.fadeFilterBtn then self.fadeFilterBtn:SetShown(showNormalFilters) end
    if self.duplicatesFilterBtn then self.duplicatesFilterBtn:SetShown(showDuplicates) end
    if self.presetsFilterBtn then
        setButtonTextColor(self.presetsFilterBtn, 1, 1, 1)
        self.presetsFilterBtn:SetText("Presets")
        self.presetsFilterBtn:SetShown(true)
    end

    local lastDropdown = self.filtersLabel
    if lastDropdown then
        local dropdownBtns = {
            self.sourceFilterBtn,
            self.qualityFilterBtn,
            self.statsFilterBtn,
            self.vendorTypeFilterBtn,
            self.typeFilterBtn,
            self.slotsFilterBtn,
            self.usableByFilterBtn,
            self.favoritesFilterBtn,
            self.collectedMEFilterBtn,
            self.duplicatesFilterBtn,
            self.presetsFilterBtn,
        }

        for _, btn in ipairs(dropdownBtns) do
            if btn and btn:IsShown() then
                btn:ClearAllPoints()
                local spacing = (lastDropdown == self.filtersLabel) and 5 or 3
                btn:SetPoint("LEFT", lastDropdown, "RIGHT", spacing, 0)
                lastDropdown = btn
            end
        end
    end

    local lastQuick = nil
    if self.quickFiltersFrame then
        local quickBtns = {
            self.lootedFilterBtn,
            self.lsFilterBtn,
            self.fadeFilterBtn,
        }
        for _, btn in ipairs(quickBtns) do
            if btn and btn:IsShown() then
                btn:ClearAllPoints()
                if lastQuick then
                    btn:SetPoint("LEFT", lastQuick, "RIGHT", 3, 0)
                else
                    btn:SetPoint("LEFT", self.quickFiltersFrame, "LEFT", 0, 0)
                end
                lastQuick = btn
            end
        end
    end
    
    if pTime then L:ProfileStop("Viewer:UpdateFilterButtonStates", pTime) end
    if self.UpdateFilterMapButton then self:UpdateFilterMapButton() end
end

function Viewer:UpdateRefreshButton()
    if not self.refreshDataBtn then return end
    
    local count = self.pendingUpdatesCount or 0
    local btn = self.refreshDataBtn
    if count > 0 then
        
        if btn.label then
            btn.label:SetText("|cff00ff00Refresh (New)|r")
        end
        btn:Enable()
        if btn.bgInner then btn.bgInner:SetVertexColor(0.05, 0.22, 0.10, 1) end
    else
        
        if btn.label then
            btn.label:SetText("|cff44aaffRefresh|r")
        end
        btn:Disable()
        if btn.bgInner then btn.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.90) end
    end
    if self.UpdateSyncStatus then self:UpdateSyncStatus() end
end

function Viewer:UpdateSyncStatus()
    if not self.syncStatusText then return end
    local Comm = L:GetModule("Comm", true)
    if not Comm or not Comm.GetPublicChannelCongestionStatus then
        self.syncStatusText:SetText("")
        if self.syncStatusHit then self.syncStatusHit:Hide() end
        return
    end
    local st = Comm:GetPublicChannelCongestionStatus()
    if not st.active then
        self.syncStatusText:SetText("|cff888888Sync: Off|r")
    elseif st.suspended then
        self.syncStatusText:SetText(string.format(
            "|cffff0000Sync: Suspended|r |cff888888(%ds)|r",
            st.remaining or 0
        ))
    elseif st.label == "Quiet" or st.label == "Active" then
        self.syncStatusText:SetText(string.format("|cff%sSync: %s|r", st.colorHex, st.label))
    else
        self.syncStatusText:SetText(string.format(
            "|cff%sSync: %s|r |cff888888(%d/min)|r",
            st.colorHex, st.label, st.mpm
        ))
    end

    if self.syncStatusHit then
        local w = self.syncStatusText:GetStringWidth() or 0
        self.syncStatusHit:SetWidth(math.max(60, w + 8))
        self.syncStatusHit:Show()
        if GameTooltip:IsOwned(self.syncStatusHit) then
            self:ShowSyncStatusTooltip(self.syncStatusHit)
        end
    end
end

function Viewer:ShowSyncStatusTooltip(owner)
    local Comm = L:GetModule("Comm", true)
    local st = Comm and Comm.GetPublicChannelCongestionStatus and Comm:GetPublicChannelCongestionStatus() or nil

    GameTooltip:SetOwner(owner or self.syncStatusHit or self.window, "ANCHOR_BOTTOM")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Public Channel Sync", 1, 0.82, 0)

    if not st or not st.active then
        GameTooltip:AddLine("Status: Off — not joined to the public sync channel.", 1, 1, 1, true)
        GameTooltip:AddLine("To join: /lc → Behavior & Sharing → Sharing Controls → enable Enable Sharing and Enable Public Channel Sync.", 0.8, 0.8, 0.8, true)
    elseif st.suspended then
        GameTooltip:AddLine(string.format(
            "Status: Suspended — temporarily left because traffic was high (%d msgs/min).",
            st.mpm or 0
        ), 1, 0.4, 0.4, true)
        if st.remaining and st.remaining > 0 then
            GameTooltip:AddLine(string.format("Auto-rejoin in about %d seconds.", st.remaining), 1, 1, 1, true)
        else
            GameTooltip:AddLine("Will rejoin automatically when traffic cools down.", 1, 1, 1, true)
        end
        GameTooltip:AddLine("This is the Auto-Pause Shield, not a permanent leave.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("To leave for good: /lc → Behavior & Sharing → Sharing Controls → turn off Enable Public Channel Sync (or Enable Sharing).", 0.8, 0.8, 0.8, true)
    else
        local stateLine = string.format("Status: %s", st.label or "?")
        if st.label ~= "Quiet" and st.label ~= "Active" then
            stateLine = string.format("%s (%d msgs/min)", stateLine, st.mpm or 0)
        end
        GameTooltip:AddLine(stateLine, 1, 1, 1, true)

        if st.label == "Quiet" or st.label == "Active" then
            GameTooltip:AddLine("Channel is joined and traffic is manageable. Discoveries sync with other players.", 0.8, 0.8, 0.8, true)
        elseif st.label == "Busy" then
            GameTooltip:AddLine("Moderate traffic. Sharing may slow down to protect performance.", 0.8, 0.8, 0.8, true)
        elseif st.label == "Congested" or st.label == "Extreme" then
            GameTooltip:AddLine("Heavy public-channel traffic. Outgoing sync is throttled; the Auto-Pause Shield may suspend the channel if it stays this high.", 0.8, 0.8, 0.8, true)
        end

        GameTooltip:AddLine("To leave: /lc → Behavior & Sharing → Sharing Controls → turn off Enable Public Channel Sync (or Enable Sharing).", 0.8, 0.8, 0.8, true)
    end

    GameTooltip:Show()
    GameTooltip:SetFrameStrata("TOOLTIP")
end

function Viewer:UpdateReloadHint()
    if self.hasUncachedData then
        if self.reloadBtn then self.reloadBtn:Show() end
        if self.reloadText then self.reloadText:Show() end
    else
        if self.reloadBtn then self.reloadBtn:Hide() end
        if self.reloadText then self.reloadText:Hide() end
    end
end

function Viewer:UpdateWorldforgedTabLabel()
    if not self.equipmentBtn then return end
    local phaseID = L.db.profile.viewer.worldforgedPhase or 0
    local labelText = "Worldforged"
    if phaseID > 0 then
        labelText = string.format("Worldforged - |cff00ff00P%d|r", phaseID - 1)
    end
    self.equipmentBtn.label:SetText(labelText .. " ▼")
end

-- Drop queued server lookups for phase-upgrade variants that no longer
-- match the selected phase. Without this, switching phases kept draining
-- stale upgrade queries for a long time ("caching both types" flicker and
-- wasted server traffic).
function Viewer:PruneStaleUpgradeCacheQueue(newPhase)
    local queue = L.db and L.db.global and L.db.global.cacheQueue
    if not queue or #queue == 0 then return end
    local CoreM = L:GetModule("Core", true)
    local kept, removed = {}, 0
    for i = 1, #queue do
        local raw = queue[i]
        local id = tonumber(raw)
        local keep = true
        if id then
            local baseID = L:GetBaseItemID(id)
            if baseID ~= id then
                -- Upgrade variant: keep only if it belongs to the phase
                -- that is selected right now.
                keep = (tonumber(newPhase) or 0) > 0
                    and L:GetWorldforgedPhaseItemID(baseID, newPhase) == id
            end
        end
        if keep then
            kept[#kept + 1] = raw
        else
            removed = removed + 1
            if CoreM and CoreM._queueSet and id then CoreM._queueSet[id] = nil end
        end
    end
    if removed > 0 then
        wipe(queue)
        for i = 1, #kept do queue[i] = kept[i] end
        self.cacheQueueMax = 0
    end
end

function Viewer:PrewarmActivePhaseUpgrades()
    local selectedPhase = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.worldforgedPhase or 0
    if selectedPhase <= 0 then return end
    
    local baseList = L.WorldforgedList
    if not baseList then return end
    
    local upgradeIDs = {}
    local added = {}
    for _, baseID in ipairs(baseList) do
        local upgradeID = L:GetWorldforgedPhaseItemID(baseID, selectedPhase)
        if upgradeID and upgradeID ~= baseID and not added[upgradeID] then
            table.insert(upgradeIDs, upgradeID)
            added[upgradeID] = true
        end
    end

    self:WarmItemIDs(upgradeIDs)

    -- FIXED "caching stuck after switching phases": the pump self-cancels
    -- when the queue empties, and nothing restarted it when a phase switch
    -- refilled the queue -- the counter froze at 0 / N.
    local CoreM = L:GetModule("Core", true)
    if CoreM and CoreM.EnsureCachePump then
        CoreM:EnsureCachePump()
    end
end

function Viewer:WarmItemIDs(idList)
    if not idList or #idList == 0 then return end
    self._warmGen = (self._warmGen or 0) + 1
    local gen = self._warmGen
    local BATCH = 50
    local idx = 1
    local function run()
        if Viewer._warmGen ~= gen then return end
        local top = idx + BATCH - 1
        if top > #idList then top = #idList end
        for i = idx, top do
            GetItemInfo(idList[i])
        end
        idx = top + 1
        if idx <= #idList then
            C_Timer.After(0.1, run)
        end
    end
    run()
end

function Viewer:CreateWindow()
    local pTime = L.ProfileStart and L:ProfileStart() 
    
    
    if not (L and L.db and L.db.profile and L.db.profile.viewer) then
        if pTime then L:ProfileStop("Viewer:CreateWindow", pTime) end
        return
    end

    if self.window then 
        if pTime then L:ProfileStop("Viewer:CreateWindow", pTime) end
        return 
    end
    
    local rowFont = _G[ROW_FONT_NAME] or CreateFont(ROW_FONT_NAME)
    rowFont:SetFont(ROW_FONT_PATH, ROW_FONT_SIZE, "")

    local uiFont = _G[UI_FONT_NAME] or CreateFont(UI_FONT_NAME)
    uiFont:SetFont(UI_FONT_PATH, UI_FONT_SIZE, "")

    local db = L.db.profile.viewer

    local window = CreateFrame("Frame", "LootCollectorViewerWindow", UIParent)
    window:SetSize(db.width or WINDOW_WIDTH, db.height or WINDOW_HEIGHT)
    window:SetMinResize(WINDOW_WIDTH, 400)
    window:SetMaxResize(1600, 1000) 
    window:SetScale(db.scale or 1.0)
    
    if db.point then
        window:ClearAllPoints()
        window:SetPoint(db.point, UIParent, db.point, db.x or 0, db.y or 0)
    else
        window:SetPoint("CENTER")
    end
    
    window:SetFrameStrata(FRAME_STRATA)
    window:SetFrameLevel(FRAME_LEVEL)
    window:SetMovable(true)
    window:SetResizable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        -- Rows stay VISIBLE while dragging. Frames whose anchors were
        -- established while the window was hidden can carry stale screen
        -- rects into the first drag (the "list left behind" ghost), so
        -- refresh the anchor-chain heads right before the move begins.
        if Viewer and Viewer.rows and Viewer.scrollFrame then
            for i, r in ipairs(Viewer.rows) do
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", Viewer.scrollFrame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            end
        end
        self:StartMoving()
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local point, _, _, x, y = self:GetPoint()
        L.db.profile.viewer.point = point
        L.db.profile.viewer.x = x
        L.db.profile.viewer.y = y

        if Viewer and Viewer.window == self then
            Viewer:UpdateLayout()

            local visibleRows = math.ceil(Viewer:GetMainScrollHeight() / ROW_HEIGHT)
            Viewer:CreateRows(visibleRows)

            Viewer:UpdateSortHeaders()
            Viewer:UpdateRows()
        end
    end)
    window:SetScript("OnMouseDown", function(self)
        CloseDropDownMenus()
    end)
    window:SetToplevel(true)
    window:Hide()

    
    window.bg = window:CreateTexture(nil, "BACKGROUND")
    window.bg:SetAllPoints(true)
    window.bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    window.bg:SetVertexColor(0.05, 0.05, 0.08, 0.85)

    
    window.border = CreateFrame("Frame", nil, window, "BackdropTemplate")
    window.border:SetAllPoints(true)
    window.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    window.border:SetBackdropBorderColor(0.2, 0.3, 0.5, 0.6)

    
    local resizeGrip = CreateFrame("Button", nil, window)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 1)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        local point = window:GetPoint()
        if point ~= "TOPLEFT" then
            local left = window:GetLeft()
            local top = window:GetTop()
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        window:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        L.db.profile.viewer.width = window:GetWidth()
        L.db.profile.viewer.height = window:GetHeight()
    end)

    local hiddenCloseBtn = CreateFrame("Button", "LootCollectorViewerHiddenClose", window)
    hiddenCloseBtn:SetScript("OnClick", function()
        if Viewer.contextMenu then
            Viewer.contextMenu:Hide()
            Viewer.contextMenu = nil
            return
        elseif Viewer.filterDropdown then
            Viewer.filterDropdown:Hide()
            Viewer.filterDropdown = nil
            return
        else
            Viewer.allowManualClose = true
            window:Hide()
        end
    end)
    hiddenCloseBtn:Hide()

    window.closeBtn = hiddenCloseBtn

    window:SetScript("OnShow", function(self)
        addToSpecialFrames(self:GetName())
    end)

    window:SetScript("OnHide", function(self)
        if Viewer.inMapOperation and not Viewer.allowManualClose then
            if Viewer.window and not Viewer.window:IsShown() then
                Viewer.window:Show()
            end
            return
        end

        if Viewer.restoreToSpecialFrames and Viewer.windowNameToRestore and not Viewer.allowManualClose then
            createTimer(0.01, function()
                if Viewer.window and not Viewer.window:IsShown() then
                    Viewer.window:Show()
                end
            end)
            return
        end

        removeFromSpecialFrames(self:GetName())
        Viewer.allowManualClose = false
    end)

    local originalHide = window.Hide
    window.Hide = function(self)
        if Viewer.inMapOperation and not Viewer.allowManualClose then return end
        originalHide(self)
    end
    originalHide(window)

    window:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    window:SetBackdropColor(0.05, 0.05, 0.08, 0.70)
    window:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)

    
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|TInterface\\AddOns\\LootCollector\\media\\MinimapIcon:28:28|t Discoveries")
    title:SetTextColor(0.85, 0.85, 1.0, 1)

    
    local titleSep = window:CreateTexture(nil, "ARTWORK")
    titleSep:SetHeight(1)
    titleSep:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -38)
    titleSep:SetPoint("TOPRIGHT", window, "TOPRIGHT", -8, -38)
    titleSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    titleSep:SetVertexColor(0.28, 0.28, 0.35, 0.8)
    
    local versionText = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionText:SetPoint("TOPLEFT", 15, -18)    
    versionText:SetTextColor(1, 0.82, 0, 1)
    versionText:SetText(string.format("LootCollector %s", L.Version or "Unknown"))

    local versionBtn = CreateFrame("Button", nil, window)
    versionBtn:SetAllPoints(versionText)
    versionBtn:EnableMouse(true)
    versionBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, -2)
        GameTooltip:SetText("LootCollector Changelog", 1, 0.82, 0)
        local text = [=[
Version 1.0.6:
- Leftover map stamps — Worldforged pins copied onto wrong maps (same item, same map fractions) merge onto the real pin on login. Looted marks move with the pin that stays.
- Verified coordinates — Verified a lot of coordinates by hand. Extra-zone copies collapse onto those pins; looted marks move with them.
- Wrong-zone copies — Fake stamps are removed for items that only spawn in one place (for example Kixxle’s potion in Wetlands, Morin’s Jug in Loch Modan, Bonechopper in Stranglethorn). Those pins are deleted, not merged onto a different item.
- Not in the game — Supply Runner’s Pants, Scholar’s Ring of Enlightenment, and The Vanishing Strap are untracked. Existing pins are removed and will not come back from loot, channel, or Starter DB.
- Worldforged upgrade tooltips — Dung–T3 upgrade lines show again on Worldforged items when Enhanced WF Tooltip is on.
- TomTom Arrow — Arrow clears on item loot correctly. No longer disappears randomly.
- Looted marks on real pins are kept. You do not need to reset any data.

Version 1.0.5:
- Public channel on for new users; Auto-Pause Shield at 5000 msgs/min; existing keep on/off.
- Decay FADING/STALE/remove; Fade All/Hide/Only; Filter Map applies Fade.
- Custom LC icon on map filter button and minimap button.
- Skip/Clear under TomTom arrow; auto-track resumes after /reload and login.

Version 1.0.4r-beta:
- Welcome tips; empty Discoveries Starter DB CTA; Sync hover tooltip.
- Zone Summary map badges; Magnify-safe map filter button; Settings cleanup.
- Shift-click chat linking; Show to… from Discoveries; removed map search bar.
- /lcarrow toggle fix + resume last tracked discovery across zones.

Version 1.0.3r-beta:
- Two-row Discoveries filters; Stats filter chips; filter Presets (save/load/delete).
- Sync status on Viewer + minimap (Quiet/Busy/Suspended); Enhanced WF Tooltip in Settings.
- Faster Refresh after live sync; less login hitch from Worldforged list warming.
- Arrow respects Filter Map; Decay cleans zone indexes; stores reporter addon version (av).
- Smoother public-channel queues under heavy traffic.

Version 1.0.2r-beta:
- Fixed Worldforged tooltip upgrade lines (Dung–T3) when hovering WF IDs.
- Armor Type filter now includes Shields; Guardian Usable By includes Polearms and Fist Weapons.
- GitHub release ZIP packages the three addon folders + README for WowUp.

Version Beta-1.0.1r:
- Merged Search + Deep Filter: Search box + Add commits chips matching name, zone, or tooltip (Deep Search checkbox removed).
- Added Filter Map: apply Discoveries filters (including search chips) to map/minimap pins and Arrow.
- Restored Worldforged Type filter (Armor/Weapon subtypes) on the Viewer Filters bar.
- Opt-in per-character Favorites (Settings); default remains shared across characters.
- Renamed Discoveries "Collected" filter to "Enchant"; hidden on CoA realms.
- Autocomplete suggests from the currently filtered Discoveries list.
- Hibernation (/lcpause) now fully stops sync, reinforce, and minimap work until resumed.
- Fixed minimap filter-cache thrash and blank/flicker spins at login.
- Faster map/Arrow filters; map Deep Filter no longer calls SetHyperlink per pin.
- Added /lcdiag <itemID|link> to dump local discoveries for an item.
- Disabled Show Zone Summary on the map menu for now.
- Fixed Honor Quartermaster buy/sell/buyback freezes (no full ScanMerchant on ordinary vendors).

Version Beta-1.0r:
- Added ~240 new & undiscovered Worldforged items into the viewer so you can see what's left to find. These were released with CoA's launch, but I don't know if all of them are in the game.
- Added Phase selection for Worldforged items, so you can see their upgrades in the Viewer and on the map.
- Made Vendors discoverable and enabled 2 more types of vendors besides Blackmarket (1 broadcast per day)
- Deep Search Tooltip Filtering: Search items by stats, spells, or effects, and filter map pins with matching keywords.
- Added the ability to filter out specific addon version and made 0.8.5 the minimum version by default. People are still using very old versions of the addon.
- Multiple ways of self-cleaning duplicates and bad items received from older addons.
- A lot of other bug fixes and performance tweaks, like the big hang when you Alt+Tab back into the game.

beta-0.8.8r:
- Filtered out incompatible Relics, Idols and Totems on CoA.
- Fixed "Unknown Realm" database splits on login.
- Merged level 60 scaled Worldforged duplicates with their base versions.
- Instantly draw pins and hide old ones when changing maps (no more lag/ghost pins).
- Blocked old synced discoveries (older than 120 days) from entering the database.
- Fixed duplicate pin trails when crossing zone borders with the map open.

beta-0.8.7r:
- Massively reduced game stuttering/lag caused by high public channel traffic.
- Smart queue system that delays outgoing updates when the server is crowded.
- Configurable performance shield to automatically pause sync during extreme spam storms.
- Fixed a memory leak and Lua errors caused by incoming message build-ups under heavy load.
- Reworked Map Filter button and anchored it to the game's Map Filter button by default.
- Removed status fading and stale transitions from decay scan.

beta-0.8.6r:
- Fixed "block too big" memory allocation error in dungeons.
- Fixed item info signature mismatch and map pin refresh crash.
- Disabled peer-to-peer version update check popups.
- Added database loading progress bar at the bottom of the viewer.
]=]
        for line in string.gmatch(text, "([^\n\r]+)") do
            if string.find(line, "^%-") then
                local bullet = string.gsub(line, "^%-%s*", "")
                GameTooltip:AddLine("• " .. bullet, 1, 1, 1, true)
            else
                GameTooltip:AddLine(line, 1.0, 0.82, 0.0, false)
            end
        end

        GameTooltip:Show()
    end)
    versionBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local function SkinButton(btn)
        if not btn then return end
        btn:SetNormalTexture("")
        btn:SetPushedTexture("")
        btn:SetHighlightTexture("")
        btn:SetBackdrop(nil)
        
        local fs = btn:GetFontString()
        if not fs then
            fs = btn:CreateFontString(nil, "OVERLAY")
            btn:SetFontString(fs)
        end
        fs:SetFontObject(UI_FONT_NAME)
        fs:SetTextColor(0.85, 0.85, 1.0)
        fs:SetPoint("CENTER", 0, 0)
        
        btn:HookScript("OnEnter", function(self) self:GetFontString():SetTextColor(1, 1, 1) end)
        btn:HookScript("OnLeave", function(self) self:GetFontString():SetTextColor(0.85, 0.85, 1.0) end)
    end

    local closeBtn = CreateFrame("Button", nil, window)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetSize(22, 22)
    SkinButton(closeBtn)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function()
        Viewer.allowManualClose = true
        window:Hide()
    end)
    closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Close")
        GameTooltip:Show()
        self:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() self:SetBackdropBorderColor(1, 1, 1, 0.5) end)
    
    local scaleUp = CreateFrame("Button", nil, window)
    scaleUp:SetSize(22, 22)
    scaleUp:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    SkinButton(scaleUp)
    scaleUp:SetText("+")
    scaleUp:SetScript("OnClick", function() 
        local newScale = math.min(window:GetScale() + 0.1, 2.0)
        window:SetScale(newScale) 
        L.db.profile.viewer.scale = newScale 
    end)
    scaleUp:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Increase Scale")
        GameTooltip:Show()
        self:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    scaleUp:SetScript("OnLeave", function(self) GameTooltip:Hide() self:SetBackdropBorderColor(1, 1, 1, 0.5) end)
    
    local scaleDown = CreateFrame("Button", nil, window)
    scaleDown:SetSize(22, 22)
    scaleDown:SetPoint("RIGHT", scaleUp, "LEFT", -5, 0)
    SkinButton(scaleDown)
    scaleDown:SetText("-")
    scaleDown:SetScript("OnClick", function() 
        local newScale = math.max(window:GetScale() - 0.1, 0.5)
        window:SetScale(newScale) 
        L.db.profile.viewer.scale = newScale 
    end)
    scaleDown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Decrease Scale")
        GameTooltip:Show()
        self:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    scaleDown:SetScript("OnLeave", function(self) GameTooltip:Hide() self:SetBackdropBorderColor(1, 1, 1, 0.5) end)


    
    window.SkinScrollBar = function(self, scrollFrame)
        local name = scrollFrame:GetName()
        if not name then return end
        local scrollbar = _G[name.."ScrollBar"]
        if not scrollbar then return end
        
        local up = _G[name.."ScrollBarScrollUpButton"]
        local down = _G[name.."ScrollBarScrollDownButton"]
        if up then up:Hide() up:SetScale(0.0001) end
        if down then down:Hide() down:SetScale(0.0001) end
        
        local thumb = scrollbar:GetThumbTexture()
        if thumb then
            thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
            thumb:SetVertexColor(1, 1, 1, 0.5)
            thumb:SetWidth(8)
        end
        
        scrollbar:SetWidth(10)
    end
     
    self.SetSelectedRow = function(self, row)
        if self.selectedRow and self.selectedRow.highlight then
            self.selectedRow.highlight:Hide()
        end
        if row and row.highlight then
            row.highlight:Show()
            self.selectedRow = row
        else
            self.selectedRow = nil
        end
    end

    
    local function CreateTabBtn(parent, label, anchorFrame, anchorPoint, tooltipText)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        if anchorFrame then
            btn:SetPoint("LEFT", anchorFrame, anchorPoint or "RIGHT", 8, 0)
        end
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(true)
        btn.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.bg:SetVertexColor(0.10, 0.10, 0.16, 0.85)
        btn.accent = btn:CreateTexture(nil, "BORDER")
        btn.accent:SetHeight(2)
        btn.accent:SetPoint("BOTTOMLEFT", 0, 0)
        btn.accent:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.accent:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.accent:SetVertexColor(0.30, 0.30, 0.40, 0.80)
        btn.bgInner = btn:CreateTexture(nil, "ARTWORK")
        btn.bgInner:SetPoint("TOPLEFT", 1, -1)
        btn.bgInner:SetPoint("BOTTOMRIGHT", -1, 2)
        btn.bgInner:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.90)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 2)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        btn:SetHighlightTexture(hl)
        btn.label = btn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
        btn.label:SetAllPoints(true)
        btn.label:SetText(label)
        btn.label:SetTextColor(0.75, 0.75, 0.80, 1)
        btn.label:SetJustifyH("CENTER")
        btn:SetScript("OnEnter", function(self)
            if not self._isActive then
                self.bgInner:SetVertexColor(0.14, 0.14, 0.22, 0.95)
                self.label:SetTextColor(1, 1, 1, 1)
            end
            if tooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(tooltipText, 1, 1, 1)
                GameTooltip:Show()
                GameTooltip:SetFrameStrata("TOOLTIP")
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self._isActive then
                self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.90)
                self.label:SetTextColor(0.75, 0.75, 0.80, 1)
            end
            GameTooltip:Hide()
        end)
        btn._isActive = false
        btn.SetActive = function(self, active)
            self._isActive = active
            if active then
                self.bgInner:SetVertexColor(0.12, 0.22, 0.38, 1)
                self.accent:SetVertexColor(0.30, 0.65, 1.0, 1)
                self.label:SetTextColor(0.30, 0.75, 1.0, 1)
            else
                self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.90)
                self.accent:SetVertexColor(0.30, 0.30, 0.40, 0.80)
                self.label:SetTextColor(0.75, 0.75, 0.80, 1)
            end
        end
        return btn
    end

    local Core = L:GetModule("Core", true)
    local isCoA = Core and Core.IsConfirmedCoARealm and Core:IsConfirmedCoARealm()

    local equipmentBtn = CreateTabBtn(window, "Worldforged", nil, nil, nil)
    equipmentBtn:SetWidth(150)
    self.equipmentBtn = equipmentBtn
    self:UpdateWorldforgedTabLabel()

    local function OpenWorldforgedPhaseMenu(selfBtn)
        -- Toggle behavior: clicking the button while our phase menu is open
        -- closes it instead of instantly reopening.
        if DropDownList1 and DropDownList1:IsShown()
            and UIDROPDOWNMENU_OPEN_MENU == Viewer._worldforgedPhaseMenuFrame then
            CloseDropDownMenus()
            return
        end
        local menu = {}
        for phase = 0, 6 do
            local phaseID = phase
            table.insert(menu, {
                text = WORLDFORGED_PHASES[phaseID],
                checked = (L.db.profile.viewer.worldforgedPhase or 0) == phaseID,
                func = function()
                    L.db.profile.viewer.worldforgedPhase = phaseID
                    Viewer.currentPage = 1
                    Cache.discoveriesBuilt = false
                    Cache.filteredResults = {}
                    Cache.lastFilterState = nil
                    Viewer:UpdateWorldforgedTabLabel()
                    Viewer:PruneStaleUpgradeCacheQueue(phaseID)
                    -- Bump warm gen so any prior WarmItemIDs / WorldforgedList
                    -- phase timers stop before the new phase warm starts.
                    Viewer._warmGen = (Viewer._warmGen or 0) + 1
                    Viewer:PrewarmActivePhaseUpgrades()
                    Viewer:RefreshData()
                    local Map = L:GetModule("Map", true)
                    if Map then
                        Map.cacheIsDirty = true
                        Map:Update(true)
                        Map:UpdateMinimap()
                    end
                end,
            })
        end
        Viewer._worldforgedPhaseMenuFrame = Viewer._worldforgedPhaseMenuFrame or CreateFrame("Frame", "LootCollectorWorldforgedPhaseMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, Viewer._worldforgedPhaseMenuFrame, selfBtn, 0, -5, "MENU")
    end

    equipmentBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    equipmentBtn:HookScript("OnEnter", function(selfBtn)
        GameTooltip:SetOwner(selfBtn, "ANCHOR_TOP")
        GameTooltip:SetText("Worldforged items found around the world by other players.", 1, 0.82, 0)
        GameTooltip:AddLine("\nClick when active or Right-Click to change upgrade phase.", 1, 1, 1)
        GameTooltip:Show()
        GameTooltip:SetFrameStrata("TOOLTIP")
    end)
    equipmentBtn:SetPoint("TOPLEFT", 20, -47)
    equipmentBtn:SetScript("OnClick", function(selfBtn, button)
        if button == "RightButton" or (selfBtn._isActive and self.currentFilter == "eq") then
            OpenWorldforgedPhaseMenu(selfBtn)
        else
            self.currentFilter = "eq"
            self.currentPage   = 1
            
            self.sortColumn    = "name"
            self.sortAscending = true
            
            self:SetSelectedRow(nil)
            if self.vendorInventoryFrame then
                self.vendorInventoryFrame:Hide()
                self.selectedVendorGuid = nil
            end
            self:UpdateFilterButtons()
            self:UpdateSortHeaders()
            self:RefreshData()
        end
    end)

    local mysticBtn = CreateTabBtn(window, "Mystic Scrolls", equipmentBtn, "RIGHT", nil)
    mysticBtn:HookScript("OnEnter", function(self)
        if not isCoA then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Mystic Scrolls found around the world by other players.", 1, 0.82, 0)
            GameTooltip:Show()
            GameTooltip:SetFrameStrata("TOOLTIP")
        end
    end)
    mysticBtn:HookScript("OnLeave", GameTooltip_Hide)
    mysticBtn:SetScript("OnClick", function()
        self.currentFilter = "ms"
        self.currentPage   = 1
        
        self.sortColumn    = "name"
        self.sortAscending = true
        
        self:SetSelectedRow(nil)
        if self.vendorInventoryFrame then
            self.vendorInventoryFrame:Hide()
            self.selectedVendorGuid = nil
        end
        self:UpdateFilterButtons()
        self:UpdateSortHeaders()
        self:RefreshData()
    end)

    local bmvBtn
    if isCoA then
        mysticBtn:Hide()
        bmvBtn = CreateTabBtn(window, "Vendors", equipmentBtn, "RIGHT", nil)
    else
        bmvBtn = CreateTabBtn(window, "Vendors", mysticBtn, "RIGHT", nil)
    end
    
    bmvBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("NPCs around the world selling Mystic Enchants, Recipes and Special items.", 1, 0.82, 0)
    end)
    bmvBtn:HookScript("OnLeave", GameTooltip_Hide)
    bmvBtn:SetScript("OnClick", function()
        self.currentFilter = "bmv"
        self.currentPage   = 1
        
        self.sortColumn    = "vendorType"
        self.sortAscending = true
        
        self:SetSelectedRow(nil)
        if self.vendorInventoryFrame then
            self.vendorInventoryFrame:Hide()
            self.selectedVendorGuid = nil
        end
        self:UpdateFilterButtons()
        self:UpdateSortHeaders()
        self:RefreshData()
    end)

    if isCoA then
        mysticBtn:Disable()
        local function showCoADisabledTooltip(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
            GameTooltip:SetText("Feature Disabled", 1, 0.82, 0)
            GameTooltip:AddLine("Mystic Scrolls do not exist on Conquest of Azeroth realms.", 1, 1, 1, true)
            GameTooltip:Show()
            GameTooltip:SetFrameStrata("TOOLTIP") 
        end
        mysticBtn:SetScript("OnEnter", showCoADisabledTooltip)
        mysticBtn:SetScript("OnLeave", GameTooltip_Hide)
    end

    local refreshDataBtn = CreateFrame("Button", nil, window)
    refreshDataBtn:SetSize(60, BUTTON_HEIGHT)
    refreshDataBtn:SetPoint("TOPRIGHT", window, "TOPRIGHT", -25, -70)
    
    refreshDataBtn.bg = refreshDataBtn:CreateTexture(nil, "BACKGROUND")
    refreshDataBtn.bg:SetAllPoints(true)
    refreshDataBtn.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    refreshDataBtn.bg:SetVertexColor(0.12, 0.12, 0.16, 0.85)

    refreshDataBtn.bgInner = refreshDataBtn:CreateTexture(nil, "ARTWORK")
    refreshDataBtn.bgInner:SetPoint("TOPLEFT", 1, -1)
    refreshDataBtn.bgInner:SetPoint("BOTTOMRIGHT", -1, 1)
    refreshDataBtn.bgInner:SetTexture("Interface\\Buttons\\WHITE8X8")
    refreshDataBtn.bgInner:SetVertexColor(0.20, 0.20, 0.26, 0.90)

    refreshDataBtn.label = refreshDataBtn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    refreshDataBtn.label:SetAllPoints(true)
    refreshDataBtn.label:SetText("Refresh")
    refreshDataBtn.label:SetJustifyH("CENTER")
    
    refreshDataBtn:SetScript("OnEnter", function(self)
        if (Viewer.pendingUpdatesCount or 0) > 0 then
            self.bgInner:SetVertexColor(0.08, 0.30, 0.14, 1)
        else
            self.bgInner:SetVertexColor(0.25, 0.35, 0.50, 1)
        end
    end)
    refreshDataBtn:SetScript("OnLeave", function(self)
        if (Viewer.pendingUpdatesCount or 0) > 0 then
            self.bgInner:SetVertexColor(0.05, 0.22, 0.10, 1)
        else
            self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.90)
        end
    end)
    refreshDataBtn:SetScript("OnMouseDown", function(self) self.label:SetPoint("TOPLEFT", 1, -2) end)
    refreshDataBtn:SetScript("OnMouseUp", function(self) self.label:SetPoint("TOPLEFT", 0, 0) end)
    refreshDataBtn:SetScript("OnClick", function()
        if Viewer._pendingTrace and #Viewer._pendingTrace > 0 then
            Viewer:DumpPendingTrace(true)
        end
        Viewer.pendingUpdatesCount = 0
        Viewer._suppressPendingBumps = true
        Viewer:UpdateRefreshButton()
        if Viewer._suppressPendingTimer and C_Timer.CancelTimer then
            C_Timer.CancelTimer(Viewer._suppressPendingTimer)
            Viewer._suppressPendingTimer = nil
        end
        Viewer._suppressPendingTimer = C_Timer.After(1.5, function()
            Viewer._suppressPendingTimer = nil
            Viewer._suppressPendingBumps = false
            VDebug("pending-bump suppress ended (Refresh click)")
        end)

        if Cache.discoveriesBuilt and not Cache.discoveriesBuilding then
            InvalidateViewerFilterCache()
            VDebug("Refresh clicked: cheap refilter (cache already built)")
            Viewer:RefreshData()
        else
            Cache.discoveriesBuilt = false
            VDebug("Refresh clicked: pending cleared, full rebuild starting")
            Viewer:RefreshData()
        end
    end)
    
    local searchLabel = window:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    searchLabel:SetPoint("TOPLEFT", equipmentBtn, "BOTTOMLEFT", 0, -10)
    searchLabel:SetText("Search: ")
    self.searchLabel = searchLabel

    local searchBox = CreateFrame("EditBox", nil, window)
    searchBox:SetSize(180, 18)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(UI_FONT_NAME)
    searchBox:SetTextColor(1, 1, 1, 1)
    
    local sbBg = searchBox:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints(true)
    sbBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    sbBg:SetVertexColor(0.08, 0.08, 0.14, 0.90)
    local sbBorder = searchBox:CreateTexture(nil, "BORDER")
    sbBorder:SetPoint("TOPLEFT", -1, 1)
    sbBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    sbBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    sbBorder:SetVertexColor(0.30, 0.30, 0.40, 0.80)

    local clearBtn = CreateFrame("Button", nil, searchBox)
    clearBtn:SetSize(24, 24)
    clearBtn:SetPoint("RIGHT", searchBox, "RIGHT", -1, 0)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    clearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    clearBtn:SetScript("OnClick", function()
        if Viewer.searchTypingTimer then C_Timer.CancelTimer(Viewer.searchTypingTimer) end
        searchBox:SetText("")
        searchBox:ClearFocus()
        clearBtn:Hide()
    end)
    clearBtn:Hide() 
    
    local searchAddBtn = CreateFrame("Button", nil, window)
    searchAddBtn:SetSize(48, 18)
    searchAddBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    searchAddBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    searchAddBtn:SetBackdropColor(0.12, 0.20, 0.14, 0.90)
    searchAddBtn:SetBackdropBorderColor(0.40, 0.60, 0.40, 0.90)
    local searchAddBtnText = searchAddBtn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    searchAddBtnText:SetPoint("CENTER", 0, 0)
    searchAddBtnText:SetText("Add")
    searchAddBtn:SetFontString(searchAddBtnText)

    local reqLevelLabel = window:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    reqLevelLabel:SetPoint("LEFT", searchAddBtn, "RIGHT", 15, 0)
    reqLevelLabel:SetText("|cffaaaaaa Req Lvl:|r")

    local minReqLevelBox = CreateFrame("EditBox", nil, window)
    minReqLevelBox:SetSize(32, 16)
    minReqLevelBox:SetPoint("LEFT", reqLevelLabel, "RIGHT", 4, 0)
    minReqLevelBox:SetAutoFocus(false)
    minReqLevelBox:SetNumeric(true)
    minReqLevelBox:SetMaxLetters(3)
    minReqLevelBox:SetFontObject(UI_FONT_NAME)
    minReqLevelBox:SetTextColor(1, 1, 1, 1)
    minReqLevelBox:SetJustifyH("CENTER")
    
    local minBg = minReqLevelBox:CreateTexture(nil, "BACKGROUND")
    minBg:SetAllPoints(true)
    minBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    minBg:SetVertexColor(0.08, 0.08, 0.14, 0.90)
    local minBorder = minReqLevelBox:CreateTexture(nil, "BORDER")
    minBorder:SetPoint("TOPLEFT", -1, 1)
    minBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    minBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    minBorder:SetVertexColor(0.30, 0.30, 0.40, 0.80)

    local dashLabel = window:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    dashLabel:SetPoint("LEFT", minReqLevelBox, "RIGHT", 3, 0)
    dashLabel:SetText("-")

    local maxReqLevelBox = CreateFrame("EditBox", nil, window)
    maxReqLevelBox:SetSize(32, 16)
    maxReqLevelBox:SetPoint("LEFT", dashLabel, "RIGHT", 3, 0)
    maxReqLevelBox:SetAutoFocus(false)
    maxReqLevelBox:SetNumeric(true)
    maxReqLevelBox:SetMaxLetters(3)
    maxReqLevelBox:SetFontObject(UI_FONT_NAME)
    maxReqLevelBox:SetTextColor(1, 1, 1, 1)
    maxReqLevelBox:SetJustifyH("CENTER")
    
    local maxBg = maxReqLevelBox:CreateTexture(nil, "BACKGROUND")
    maxBg:SetAllPoints(true)
    maxBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    maxBg:SetVertexColor(0.08, 0.08, 0.14, 0.90)
    local maxBorder = maxReqLevelBox:CreateTexture(nil, "BORDER")
    maxBorder:SetPoint("TOPLEFT", -1, 1)
    maxBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    maxBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    maxBorder:SetVertexColor(0.30, 0.30, 0.40, 0.80)

    ------------------------------------------------------------------
    -- Search chips (Deep Filter list): Add via search box; manage in Filters panel
    ------------------------------------------------------------------
    if L.db and L.db.profile then
        if type(L.db.profile.deepSearchFilters) ~= "table" then L.db.profile.deepSearchFilters = {} end
        Viewer.deepSearchFilters = L.db.profile.deepSearchFilters
    else
        Viewer.deepSearchFilters = Viewer.deepSearchFilters or {}
    end
    Viewer:RebuildDeepCompiled()

    local DFB_H = BUTTON_HEIGHT or 22

    local deepFilterBtn = CreateFrame("Button", nil, window)
    deepFilterBtn:SetSize(96, DFB_H)
    deepFilterBtn:SetPoint("LEFT", maxReqLevelBox, "RIGHT", 12, 0)
    deepFilterBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    deepFilterBtn:SetBackdropColor(0.10, 0.10, 0.16, 0.90)
    deepFilterBtn:SetBackdropBorderColor(0.30, 0.30, 0.45, 0.85)
    local dfbText = deepFilterBtn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    dfbText:SetPoint("CENTER", 0, 0)
    deepFilterBtn:SetFontString(dfbText)

    -- Chip list panel (no add box — search row commits chips)
    local deepPanel = CreateFrame("Frame", "LCDeepFilterPanel", window)
    deepPanel:SetSize(250, 190)
    deepPanel:SetPoint("TOPLEFT", deepFilterBtn, "BOTTOMLEFT", 0, -4)
    deepPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    deepPanel:SetToplevel(true)
    deepPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    deepPanel:SetBackdropColor(0.06, 0.06, 0.10, 0.97)
    deepPanel:SetBackdropBorderColor(0.35, 0.35, 0.55, 0.9)
    deepPanel:EnableMouse(true)
    deepPanel:Hide()
    deepPanel.rows = {}

    local dpTitle = deepPanel:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    dpTitle:SetPoint("TOPLEFT", 10, -8)
    dpTitle:SetText("Active Searches")
    dpTitle:SetTextColor(1, 0.82, 0)

    local listContainer = CreateFrame("Frame", nil, deepPanel)
    listContainer:SetPoint("TOPLEFT", 10, -28)
    listContainer:SetPoint("TOPRIGHT", -10, -28)
    listContainer:SetHeight(130)

    local dpHint = deepPanel:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    dpHint:SetPoint("BOTTOMLEFT", 10, 8)
    dpHint:SetPoint("BOTTOMRIGHT", -10, 8)
    dpHint:SetJustifyH("LEFT")
    dpHint:SetTextColor(0.55, 0.55, 0.60)
    dpHint:SetText("Matches name, zone, or tooltip. Each chip narrows further. Use AND / OR in a chip.")

    local function colorizeExpr(s)
        s = s:gsub("(%s)([Aa][Nn][Dd])(%s)", "%1|cff66ccff%2|r%3")
        s = s:gsub("(%s)([Oo][Rr])(%s)", "%1|cffff9944%2|r%3")
        return s
    end

    function Viewer:RefreshDeepFilterPanel()
        local filters = self.deepSearchFilters or {}
        local n = #filters
        if n > 0 then
            dfbText:SetText("Filters (" .. n .. ")")
            dfbText:SetTextColor(1, 0.82, 0)
            deepFilterBtn:SetBackdropBorderColor(1, 0.82, 0, 0.95)
        else
            dfbText:SetText("Filters")
            dfbText:SetTextColor(0.90, 0.90, 0.90)
            deepFilterBtn:SetBackdropBorderColor(0.30, 0.30, 0.45, 0.85)
        end

        for _, r in ipairs(deepPanel.rows) do r:Hide() end
        for i = 1, n do
            local row = deepPanel.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, listContainer)
                row:SetHeight(18)
                row.label = row:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
                row.label:SetPoint("LEFT", 2, 0)
                row.label:SetPoint("RIGHT", -20, 0)
                row.label:SetJustifyH("LEFT")
                row.del = CreateFrame("Button", nil, row)
                row.del:SetSize(16, 16)
                row.del:SetPoint("RIGHT", 0, 0)
                row.del:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
                row.del:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
                row.del:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
                row.del:SetScript("OnClick", function(self2)
                    local idx = self2.filterIndex
                    if idx then
                        _tremove(Viewer.deepSearchFilters, idx)
                        Viewer:RebuildDeepCompiled()
                        Viewer:RefreshDeepFilterPanel()
                        Viewer.currentPage = 1
                        Viewer:RefreshData()
                        Viewer:UpdateClearAllButton()
                        Viewer:NotifyMapDeepFilterChanged()
                    end
                end)
                deepPanel.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            row:SetPoint("TOPRIGHT", 0, -(i - 1) * 20)
            row.label:SetText(colorizeExpr(filters[i]))
            row.del.filterIndex = i
            row:Show()
        end
    end

    local function addDeepExpr()
        if Viewer.searchTypingTimer then C_Timer.CancelTimer(Viewer.searchTypingTimer) end
        local t = searchBox:GetText()
        t = t and strtrim(t) or ""
        if t ~= "" then
            local lower = string.lower(t)
            local exists = false
            for i = 1, #Viewer.deepSearchFilters do
                if string.lower(Viewer.deepSearchFilters[i]) == lower then exists = true; break end
            end
            if not exists then _tinsert(Viewer.deepSearchFilters, t) end
        end
        searchBox:SetText("")
        clearBtn:Hide()
        searchBox:ClearFocus()
        Viewer:RebuildDeepCompiled()
        Viewer:RefreshDeepFilterPanel()
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:NotifyMapDeepFilterChanged()
    end
    searchAddBtn:SetScript("OnClick", addDeepExpr)

    deepFilterBtn:SetScript("OnClick", function()
        if deepPanel:IsShown() then
            deepPanel:Hide()
        else
            Viewer:RefreshDeepFilterPanel()
            deepPanel:SetFrameStrata("FULLSCREEN_DIALOG")
            deepPanel:SetFrameLevel((window:GetFrameLevel() or 1) + 50)
            deepPanel:Show()
            deepPanel:Raise()
        end
    end)
    deepFilterBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Active Searches", 1, 1, 1)
        GameTooltip:AddLine("Shows search chips added from the Search box.", 1, 0.82, 0, true)
        GameTooltip:AddLine("Each chip matches item name, zone, or tooltip. Use AND / OR inside a chip.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show(); GameTooltip:SetFrameStrata("TOOLTIP")
    end)
    deepFilterBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Viewer.deepFilterPanel = deepPanel
    Viewer.searchBox = searchBox
    Viewer:RefreshDeepFilterPanel()

    -- Filter Map: apply Discoveries filters (incl. search chips) to map/minimap pins.
    local filterMapBtn = CreateFrame("Button", nil, window)
    filterMapBtn:SetSize(88, DFB_H)
    filterMapBtn:SetPoint("LEFT", deepFilterBtn, "RIGHT", 8, 0)
    filterMapBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    filterMapBtn:SetBackdropColor(0.10, 0.10, 0.16, 0.90)
    filterMapBtn:SetBackdropBorderColor(0.30, 0.30, 0.45, 0.85)
    local fmbText = filterMapBtn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    fmbText:SetPoint("CENTER", 0, 0)
    filterMapBtn:SetFontString(fmbText)
    filterMapBtn:SetText("Filter Map")
    Viewer.filterMapBtn = filterMapBtn
    Viewer.filterMapBtnText = fmbText

    function Viewer:UpdateFilterMapButton()
        if not self.filterMapBtn then return end
        local on = self:IsFilterMapEnabled()
        if on then
            self.filterMapBtn:SetBackdropBorderColor(1, 0.82, 0, 0.95)
            if self.filterMapBtnText then self.filterMapBtnText:SetTextColor(1, 0.82, 0) end
            self.filterMapBtn:SetText("Filter Map: On")
        else
            self.filterMapBtn:SetBackdropBorderColor(0.30, 0.30, 0.45, 0.85)
            if self.filterMapBtnText then self.filterMapBtnText:SetTextColor(1, 1, 1) end
            self.filterMapBtn:SetText("Filter Map")
        end
    end

    filterMapBtn:SetScript("OnClick", function()
        Viewer:SetFilterMapEnabled(not Viewer:IsFilterMapEnabled())
    end)
    filterMapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Filter Map", 1, 1, 1)
        GameTooltip:AddLine("When on, map and minimap pins use your Discoveries filters (including search chips).", 1, 0.82, 0, true)
        GameTooltip:AddLine("Map-only options (hide unconfirmed/faded, show WF/MS/vendors, etc.) still apply.", 0.8, 0.8, 0.8, true)
        local pending = Viewer._filterMapUncachedCount or 0
        if pending > 0 then
            GameTooltip:AddLine(string.format("%d pins are shown until tooltip cache fills (Stats chips). They may hide after.", pending), 1, 0.6, 0.2, true)
        end
        GameTooltip:Show(); GameTooltip:SetFrameStrata("TOOLTIP")
    end)
    filterMapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Viewer:UpdateFilterMapButton()

    refreshDataBtn:ClearAllPoints()
    refreshDataBtn:SetPoint("LEFT", filterMapBtn, "RIGHT", 12, 0)
    refreshDataBtn:SetSize(110, BUTTON_HEIGHT)

    local syncStatusHit = CreateFrame("Frame", nil, window)
    syncStatusHit:SetSize(120, BUTTON_HEIGHT)
    syncStatusHit:SetPoint("LEFT", refreshDataBtn, "RIGHT", 10, 0)
    syncStatusHit:SetFrameStrata(FRAME_STRATA)
    syncStatusHit:SetFrameLevel(FRAME_LEVEL + 2)
    syncStatusHit:EnableMouse(true)

    local syncStatusText = syncStatusHit:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    syncStatusText:SetPoint("LEFT", syncStatusHit, "LEFT", 0, 0)
    syncStatusText:SetJustifyH("LEFT")
    syncStatusText:SetText("")
    self.syncStatusText = syncStatusText
    self.syncStatusHit = syncStatusHit

    syncStatusHit:SetScript("OnEnter", function(self)
        Viewer:ShowSyncStatusTooltip(self)
    end)
    syncStatusHit:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:UpdateSyncStatus()
    
    local bugBtn = CreateFrame("Button", nil, window)
    bugBtn:SetSize(24, 24)
    bugBtn:SetPoint("TOPRIGHT", window, "TOPRIGHT", -25, -73)
    
    local bugIcon = bugBtn:CreateTexture(nil, "ARTWORK")
    bugIcon:SetAllPoints()
    bugIcon:SetTexture("Interface\\Icons\\custom_55_bug_border")
    bugIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    local bugBorder = bugBtn:CreateTexture(nil, "OVERLAY")
    bugBorder:SetAllPoints()
    bugBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    bugBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    bugBorder:SetVertexColor(0.8, 0.8, 0.8, 1)

    local bugHighlight = bugBtn:CreateTexture(nil, "HIGHLIGHT")
    bugHighlight:SetAllPoints()
    bugHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    bugHighlight:SetBlendMode("ADD")

    bugBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Report a Bug & Feedback", 1, 0.82, 0)
        GameTooltip:AddLine("Click to get the Discord link to report bugs and leave feedback in #lootcollector.", 1, 1, 1, true)
        GameTooltip:Show()
        GameTooltip:SetFrameStrata("TOOLTIP")
    end)
    
    bugBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    bugBtn:SetScript("OnClick", function()
        StaticPopup_Show("LOOTCOLLECTOR_DISCORD_BUG_REPORT")
        print("|cff00ff00LootCollector Discord Invite:|r https://discord.gg/GmeSCJGdzs")
    end)

    local function UpdateReqLevelFilter()
        if Viewer._applyingReqLevelPreset then return end
        Viewer.minReqLevel = tonumber(minReqLevelBox:GetText())
        Viewer.maxReqLevel = tonumber(maxReqLevelBox:GetText())
        if Viewer.searchTypingTimer then C_Timer.CancelTimer(Viewer.searchTypingTimer) end
        Viewer.searchTypingTimer = C_Timer.After(0.4, function()
            Viewer.currentPage = 1
            Viewer:RefreshData()
            Viewer:UpdateClearAllButton()
        end)
    end

    minReqLevelBox:SetScript("OnTextChanged", UpdateReqLevelFilter)
    minReqLevelBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    minReqLevelBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    
    maxReqLevelBox:SetScript("OnTextChanged", UpdateReqLevelFilter)
    maxReqLevelBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    maxReqLevelBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local autocompleteDropdown = nil
    local autocompleteSuggestions = {}
    local selectedSuggestionIndex = 0

    local function createAutocompleteDropdown()
        if autocompleteDropdown then return autocompleteDropdown end
        autocompleteDropdown = CreateFrame("Frame", "LootCollectorSearchAutocomplete", Viewer.window)
        autocompleteDropdown:SetSize(200, 20)
        autocompleteDropdown:SetFrameStrata("FULLSCREEN_DIALOG")
        autocompleteDropdown:SetFrameLevel((Viewer.window:GetFrameLevel() or 1) + 60)
        autocompleteDropdown:Hide()

        autocompleteDropdown:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        autocompleteDropdown:SetBackdropColor(0.1, 0.1, 0.1, 0.95)

        local content = CreateFrame("Frame", nil, autocompleteDropdown)
        content:SetPoint("TOPLEFT", 5, -5)
        content:SetPoint("BOTTOMRIGHT", -5, 5)
        content:SetFrameLevel(autocompleteDropdown:GetFrameLevel() + 1)

        autocompleteDropdown.content = content
        autocompleteDropdown.buttons = {}
        return autocompleteDropdown
    end

    local function hideAutocompleteDropdown()
        if autocompleteDropdown then
            autocompleteDropdown:Hide()
            selectedSuggestionIndex = 0
        end
    end

    local function getSearchCandidates(text)
        if not text or text == "" then return {} end
        local textLower = _strlower(text)
        local prefixLen = string.len(textLower)
        local candidates = {}
        local seen = {}
        local MAX_CANDIDATES = 10

        local rows
        if Cache.discoveriesBuilding then
            rows = (Cache.discoveriesBuilt and Cache.discoveries) or {}
        else
            local filterState = Viewer:GetFilterStateHash()
            if Cache.lastFilterState == filterState and Cache.filteredResults then
                rows = Cache.filteredResults
            else
                rows = Viewer:GetFilteredDiscoveries() or {}
            end
        end
        if not rows or #rows == 0 then return {} end

        local function consider(label)
            if not label or label == "" or seen[label] then return end
            local lower = _strlower(label)
            if string.sub(lower, 1, prefixLen) == textLower then
                seen[label] = true
                _tinsert(candidates, label)
            end
        end

        for i = 1, #rows do
            local data = rows[i]
            if data then
                if data.isVendor then
                    consider(data.vendorName)
                else
                    consider(data.itemName)
                end
                local zoneName = data.zoneNameStr
                if not zoneName and data.discovery then
                    zoneName = GetLocalizedZoneName(data.discovery)
                end
                consider(zoneName)
            end
            if #candidates >= MAX_CANDIDATES then break end
        end

        _tsort(candidates)
        return candidates
    end

    local function updateAutocompleteSelection()
        if not autocompleteDropdown or not autocompleteDropdown:IsShown() then return end
        for i, button in ipairs(autocompleteDropdown.buttons) do
            if i == selectedSuggestionIndex then
                button:GetHighlightTexture():SetVertexColor(0.5, 0.5, 0.8, 0.8)
            else
                button:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.3, 0.8)
            end
        end
    end

    local function showAutocompleteSuggestions(text)
        local candidates = getSearchCandidates(text)
        if #candidates == 0 then
            hideAutocompleteDropdown()
            return
        end

        autocompleteSuggestions = candidates
        selectedSuggestionIndex = 0

        local dropdown = createAutocompleteDropdown()
        dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdown:SetFrameLevel((Viewer.window:GetFrameLevel() or 1) + 60)
        local content = dropdown.content
        content:SetFrameLevel(dropdown:GetFrameLevel() + 1)

        for _, button in ipairs(dropdown.buttons) do button:Hide() end
        dropdown.buttons = {}

        local buttonHeight = 16
        local maxHeight = 160
        local totalHeight = math.min(#candidates * buttonHeight, maxHeight)
        dropdown:SetSize(200, totalHeight + 10)

        for i, candidate in ipairs(candidates) do
            local button = CreateFrame("Button", nil, content)
            button:SetSize(190, buttonHeight)
            button:SetPoint("TOPLEFT", 5, -(i - 1) * buttonHeight)
            button:SetFrameLevel(content:GetFrameLevel() + 1)

            local textObj = button:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
            textObj:SetPoint("LEFT", 5, 0)
            textObj:SetText(candidate)
            textObj:SetJustifyH("LEFT")
            textObj:SetTextColor(1, 1, 1)

            button:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
            button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            button:GetNormalTexture():SetVertexColor(0.1, 0.1, 0.1, 0.8)
            button:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.3, 0.8)

            button:SetScript("OnClick", function()
                searchBox:SetText(candidate)
                hideAutocompleteDropdown()
                addDeepExpr()
            end)

            button:SetScript("OnEnter", function()
                selectedSuggestionIndex = i
                updateAutocompleteSelection()
            end)

            button:Show()
            _tinsert(dropdown.buttons, button)
        end

        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -2)
        dropdown:Show()
        dropdown:Raise()
    end

    local function selectNextSuggestion()
        if not autocompleteDropdown or not autocompleteDropdown:IsShown() then return end
        selectedSuggestionIndex = selectedSuggestionIndex + 1
        if selectedSuggestionIndex > #autocompleteSuggestions then selectedSuggestionIndex = 1 end
        updateAutocompleteSelection()
    end

    local function selectPreviousSuggestion()
        if not autocompleteDropdown or not autocompleteDropdown:IsShown() then return end
        selectedSuggestionIndex = selectedSuggestionIndex - 1
        if selectedSuggestionIndex < 1 then selectedSuggestionIndex = #autocompleteSuggestions end
        updateAutocompleteSelection()
    end

    local function applySelectedSuggestion()
        if not autocompleteDropdown or not autocompleteDropdown:IsShown() then return end
        if selectedSuggestionIndex < 1 or selectedSuggestionIndex > #autocompleteSuggestions then return end
        local suggestion = autocompleteSuggestions[selectedSuggestionIndex]
        searchBox:SetText(suggestion)
        hideAutocompleteDropdown()
        addDeepExpr()
    end

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text ~= "" then
            clearBtn:Show()
            if Viewer.searchTypingTimer then C_Timer.CancelTimer(Viewer.searchTypingTimer) end
            Viewer.searchTypingTimer = C_Timer.After(0.2, function()
                showAutocompleteSuggestions(text)
            end)
        else
            clearBtn:Hide()
            hideAutocompleteDropdown()
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        if autocompleteDropdown and autocompleteDropdown:IsShown() and selectedSuggestionIndex > 0 then
            applySelectedSuggestion()
        else
            addDeepExpr()
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if autocompleteDropdown and autocompleteDropdown:IsShown() then
            hideAutocompleteDropdown()
        else
            if Viewer.searchTypingTimer then C_Timer.CancelTimer(Viewer.searchTypingTimer) end
            self:SetText("")
            self:ClearFocus()
            clearBtn:Hide()
        end
    end)
    searchBox:SetScript("OnTabPressed", function(self)
        if autocompleteDropdown and autocompleteDropdown:IsShown() and #autocompleteSuggestions > 0 then
            searchBox:SetText(autocompleteSuggestions[1])
            hideAutocompleteDropdown()
            addDeepExpr()
        end
    end)
    searchBox:SetScript("OnKeyDown", function(self, key)
        if autocompleteDropdown and autocompleteDropdown:IsShown() then
            if key == "DOWN" then selectNextSuggestion(); return true
            elseif key == "UP" then selectPreviousSuggestion(); return true
            elseif key == "ENTER" then
                if selectedSuggestionIndex > 0 then
                    applySelectedSuggestion()
                else
                    addDeepExpr()
                end
                return true
            elseif key == "ESCAPE" then hideAutocompleteDropdown(); return true
            elseif key == "TAB" then
                if #autocompleteSuggestions > 0 then
                    searchBox:SetText(autocompleteSuggestions[1])
                    hideAutocompleteDropdown()
                    addDeepExpr()
                end
                return true
            end
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        createTimer(0.1, function()
            if not searchBox:HasFocus() then hideAutocompleteDropdown() end
        end)
    end)

    -- Top strip (tab row): Looted / Date / Fade
    local quickFiltersFrame = CreateFrame("Frame", "LootCollectorQuickFiltersFrame", window, "BackdropTemplate")
    quickFiltersFrame:SetSize(280, 24)
    quickFiltersFrame:SetFrameStrata(FRAME_STRATA)
    quickFiltersFrame:SetFrameLevel(FRAME_LEVEL + 1)
    quickFiltersFrame:SetPoint("LEFT", bmvBtn, "RIGHT", 20, 0)
    quickFiltersFrame:SetBackdrop(nil)

    -- Second row: dropdown filters (Source, Quality, Type, …)
    local additionalFiltersFrame = CreateFrame("Frame", "LootCollectorAdditionalFiltersFrame", window, "BackdropTemplate")
    additionalFiltersFrame:SetSize(700, 24)
    additionalFiltersFrame:SetFrameStrata(FRAME_STRATA)
    additionalFiltersFrame:SetFrameLevel(FRAME_LEVEL + 1)
    additionalFiltersFrame:SetPoint("TOPLEFT", equipmentBtn, "BOTTOMLEFT", 0, -8)
    additionalFiltersFrame:SetBackdrop(nil)

    local filtersLabel = additionalFiltersFrame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    filtersLabel:SetPoint("LEFT", 0, 0)
    filtersLabel:SetText("Filters:")

    local function CreateFlatFilterBtn(parent, label, width, anchorFrame, anchorPoint, xOffset)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, BUTTON_HEIGHT)
        btn:SetPoint("LEFT", anchorFrame, anchorPoint or "RIGHT", xOffset or 3, 0)
        btn:SetFrameStrata(FRAME_STRATA)
        btn:SetFrameLevel(FRAME_LEVEL + 1)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(true)
        btn.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.bg:SetVertexColor(0.10, 0.10, 0.16, 0.85)
        btn.bgInner = btn:CreateTexture(nil, "ARTWORK")
        btn.bgInner:SetPoint("TOPLEFT", 1, -1)
        btn.bgInner:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.bgInner:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.92)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        btn:SetHighlightTexture(hl)
        
        btn._label = btn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
        btn._label:SetAllPoints(true)
        btn._label:SetText(label)
        btn._label:SetTextColor(0.78, 0.78, 0.85, 1)
        btn._label:SetJustifyH("CENTER")
        
        btn.GetFontString = function(self) return self._label end
        btn.SetText = function(self, text) self._label:SetText(text) end
        btn.GetText = function(self) return self._label:GetText() end
        
        btn:SetScript("OnEnter", function(self) self.bgInner:SetVertexColor(0.14, 0.14, 0.22, 0.95) end)
        btn:SetScript("OnLeave", function(self) self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.92) end)
        btn:SetScript("OnMouseDown", function(self) self.bgInner:SetVertexColor(0.10, 0.20, 0.35, 1) end)
        btn:SetScript("OnMouseUp", function(self) self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.92) end)
        return btn
    end

    local sourceFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Source", 55, filtersLabel, "RIGHT", 5)
    sourceFilterBtn:SetScript("OnClick", function(self, button)
        local values = GetUniqueValues("source")
        Viewer:ShowColumnFilterDropdown("source", self, values)
    end)
    sourceFilterBtn:RegisterForClicks("LeftButtonUp")

    local qualityFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Quality", 55, sourceFilterBtn, "RIGHT", 3)
    qualityFilterBtn:SetScript("OnClick", function(self, button)
        local values = GetUniqueValues("quality")
        Viewer:ShowColumnFilterDropdown("quality", self, values)
    end)
    qualityFilterBtn:RegisterForClicks("LeftButtonUp")

    local statsFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Stats", 45, qualityFilterBtn, "RIGHT", 3)
    statsFilterBtn:SetScript("OnClick", function(self, button)
        Viewer:ShowStatsFilterMenu(self)
    end)
    statsFilterBtn:RegisterForClicks("LeftButtonUp")

    local typeFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Type", 42, statsFilterBtn, "RIGHT", 3)
    typeFilterBtn:SetScript("OnClick", function(self, button)
        Viewer:ShowTypeFilterMenu(self)
    end)
    typeFilterBtn:RegisterForClicks("LeftButtonUp")

    local vendorTypeFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Type", 55, typeFilterBtn, "RIGHT", 3)
    vendorTypeFilterBtn:SetScript("OnClick", function(self, button)
        local values = GetUniqueValues("vendorType")
        Viewer:ShowColumnFilterDropdown("vendorType", self, values)
    end)
    vendorTypeFilterBtn:RegisterForClicks("LeftButtonUp")

    local slotsFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Slots", 42, vendorTypeFilterBtn, "RIGHT", 3)
    slotsFilterBtn:SetScript("OnClick", function(self, button)
        local values = GetUniqueValues("slot")
        Viewer:ShowColumnFilterDropdown("slot", self, values)
    end)
    slotsFilterBtn:RegisterForClicks("LeftButtonUp")

    local usableByFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Usable By", 65, slotsFilterBtn, "RIGHT", 3)
    usableByFilterBtn:SetScript("OnClick", function(self, button)
        local values = GetUniqueValues("class")
        Viewer:ShowColumnFilterDropdown("class", self, values)
    end)
    usableByFilterBtn:RegisterForClicks("LeftButtonUp")

    local favoritesFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Favorites", 75, usableByFilterBtn, "RIGHT", 3)
    favoritesFilterBtn:SetScript("OnClick", function(self, button)
        if Viewer.favoritesFilterState == nil then Viewer.favoritesFilterState = true else Viewer.favoritesFilterState = nil end
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end)
    favoritesFilterBtn:RegisterForClicks("LeftButtonUp")

    local collectedMEFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Enchant", 82, favoritesFilterBtn, "RIGHT", 3)
    collectedMEFilterBtn:SetScript("OnEnter", function(self) 
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Filter by which Mystic Enchants have been collected.")
        GameTooltip:Show() 
    end)
    collectedMEFilterBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    collectedMEFilterBtn:SetScript("OnClick", function(self, button)
        local CoreMod = L:GetModule("Core", true)
        if CoreMod and CoreMod.IsConfirmedCoARealm and CoreMod:IsConfirmedCoARealm() then
            return
        end
        if Viewer.collectedMEFilterState == nil then Viewer.collectedMEFilterState = true
        elseif Viewer.collectedMEFilterState == true then Viewer.collectedMEFilterState = false
        else Viewer.collectedMEFilterState = nil end
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end)
    collectedMEFilterBtn:RegisterForClicks("LeftButtonUp")

    local duplicatesFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Duplicates", 75, collectedMEFilterBtn, "RIGHT", 3)
    duplicatesFilterBtn:SetScript("OnClick", function(self, button)
        Viewer.columnFilters.duplicates = not Viewer.columnFilters.duplicates
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end)
    duplicatesFilterBtn:RegisterForClicks("LeftButtonUp")

    local presetsFilterBtn = CreateFlatFilterBtn(additionalFiltersFrame, "Presets", 58, duplicatesFilterBtn, "RIGHT", 3)
    presetsFilterBtn:SetScript("OnClick", function(self, button)
        Viewer:ShowPresetsFilterMenu(self)
    end)
    presetsFilterBtn:RegisterForClicks("LeftButtonUp")

    local lootedFilterBtn = CreateFlatFilterBtn(quickFiltersFrame, "Looted", 75, quickFiltersFrame, "LEFT", 0)
    lootedFilterBtn:SetScript("OnClick", function(self, button)
        if Viewer.lootedFilterState == nil then Viewer.lootedFilterState = true      
        elseif Viewer.lootedFilterState == true then Viewer.lootedFilterState = false     
        else Viewer.lootedFilterState = nil end
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end)
    lootedFilterBtn:RegisterForClicks("LeftButtonUp")

    local lsFilterBtn = CreateFlatFilterBtn(quickFiltersFrame, "Date: Off", 75, lootedFilterBtn, "RIGHT", 3)
    lsFilterBtn:SetScript("OnClick", function(self, button)
        if Viewer.lastSeenSortState == "off" or not Viewer.lastSeenSortState then Viewer.lastSeenSortState = "new"
        elseif Viewer.lastSeenSortState == "new" then Viewer.lastSeenSortState = "old"
        else Viewer.lastSeenSortState = "off" end
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end)
    lsFilterBtn:RegisterForClicks("LeftButtonUp")

    local fadeFilterBtn = CreateFlatFilterBtn(quickFiltersFrame, "Fade: All", 78, lsFilterBtn, "RIGHT", 3)
    fadeFilterBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show or hide fading and stale discoveries.")
        GameTooltip:AddLine("All: show every pin. Hide: drop fading/stale. Only: fading/stale only.", 1, 1, 1, true)
        GameTooltip:AddLine("Turn Filter Map ON to apply this to map and minimap pins.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    fadeFilterBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    fadeFilterBtn:SetScript("OnClick", function(self, button)
        if Viewer.fadeFilterState == nil then Viewer.fadeFilterState = "hide"
        elseif Viewer.fadeFilterState == "hide" then Viewer.fadeFilterState = "only"
        else Viewer.fadeFilterState = nil end
        Viewer.currentPage = 1
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        Viewer:RefreshData()
        Viewer:UpdateClearAllButton()
        Viewer:UpdateFilterButtonStates()
    end)
    fadeFilterBtn:RegisterForClicks("LeftButtonUp")
    
    self.sourceFilterBtn = sourceFilterBtn
    self.qualityFilterBtn = qualityFilterBtn
    self.statsFilterBtn = statsFilterBtn
    self.typeFilterBtn = typeFilterBtn
    self.vendorTypeFilterBtn = vendorTypeFilterBtn
    self.slotsFilterBtn = slotsFilterBtn
    self.usableByFilterBtn = usableByFilterBtn
    self.favoritesFilterBtn = favoritesFilterBtn
    self.lootedFilterBtn = lootedFilterBtn
    self.collectedMEFilterBtn = collectedMEFilterBtn
    self.duplicatesFilterBtn = duplicatesFilterBtn
    self.presetsFilterBtn = presetsFilterBtn
    self.lsFilterBtn = lsFilterBtn
    self.fadeFilterBtn = fadeFilterBtn
    self.quickFiltersFrame = quickFiltersFrame

    -- Search row sits below the dropdown filter row
    if self.searchLabel then
        self.searchLabel:ClearAllPoints()
        self.searchLabel:SetPoint("TOPLEFT", additionalFiltersFrame, "BOTTOMLEFT", 0, -8)
    end

    local headerFrame = CreateFrame("Frame", nil, window)
    headerFrame:SetSize(WINDOW_WIDTH - 40, HEADER_HEIGHT)
    headerFrame:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -10)
    headerFrame:SetFrameLevel(FRAME_LEVEL + 1)
    headerFrame:SetFrameStrata(FRAME_STRATA)

    headerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerFrame:SetBackdropColor(0.08, 0.10, 0.14, 0.95)
    headerFrame:SetBackdropBorderColor(0.20, 0.20, 0.25, 1)

    local nameHeader = CreateFrame("Button", nil, headerFrame)
    nameHeader:SetSize(GRID_LAYOUT.NAME_WIDTH, HEADER_HEIGHT)
    nameHeader:SetPoint("LEFT", 5, 0)
    nameHeader:SetText("Name")
    nameHeader:SetNormalFontObject(UI_FONT_NAME)
    nameHeader:SetHighlightFontObject(UI_FONT_NAME)
    nameHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "name" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "name"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)

    local favHeader = CreateFrame("Button", nil, headerFrame)
    favHeader:SetSize(GRID_LAYOUT.FAV_WIDTH, HEADER_HEIGHT)
    favHeader:SetPoint("LEFT", nameHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    local favHeaderIcon = favHeader:CreateTexture(nil, "ARTWORK")
    favHeaderIcon:SetSize(14, 14)
    favHeaderIcon:SetPoint("CENTER", 0, 0)
    favHeaderIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    favHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "favorite" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "favorite"; Viewer.sortAscending = false end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)
    favHeader:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Favorites", 1, 1, 1)
        GameTooltip:AddLine("Click the star next to an item to favorite it.", nil, nil, nil, true)
        if L.db and L.db.profile and L.db.profile.perCharacterFavorites then
            GameTooltip:AddLine("Favorites are saved per-character (Settings → Discoveries Window).", 1, 0.8, 0, true)
        else
            GameTooltip:AddLine("Favorites are shared across characters on this profile (opt into per-character in Settings → Discoveries Window).", 1, 0.8, 0, true)
        end
        GameTooltip:Show()
    end)
    favHeader:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    local levelHeader = CreateFrame("Button", nil, headerFrame)
    levelHeader:SetSize(GRID_LAYOUT.LEVEL_WIDTH, HEADER_HEIGHT)
    levelHeader:SetPoint("LEFT", favHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    levelHeader:SetText("Level")
    levelHeader:SetNormalFontObject(UI_FONT_NAME)
    levelHeader:SetHighlightFontObject(UI_FONT_NAME)
    levelHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "level" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "level"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)

    local slotHeader = CreateFrame("Button", nil, headerFrame)
    slotHeader:SetSize(GRID_LAYOUT.SLOT_WIDTH, HEADER_HEIGHT)
    slotHeader:SetPoint("LEFT", levelHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    slotHeader:SetText("Slot")
    slotHeader:SetNormalFontObject(UI_FONT_NAME)
    slotHeader:SetHighlightFontObject(UI_FONT_NAME)
    slotHeader:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local values = GetUniqueValues("slot")
            Viewer:ShowColumnFilterDropdown("slot", self, values)
        else
            if Viewer.sortColumn == "slot" then Viewer.sortAscending = not Viewer.sortAscending
            else Viewer.sortColumn = "slot"; Viewer.sortAscending = true end
            Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
        end
    end)
    slotHeader:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slotHeader:Hide() 

    local typeHeader = CreateFrame("Button", nil, headerFrame)
    typeHeader:SetSize(GRID_LAYOUT.TYPE_WIDTH, HEADER_HEIGHT)
    typeHeader:SetPoint("LEFT", slotHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    typeHeader:SetText("Type")
    typeHeader:SetNormalFontObject(UI_FONT_NAME)
    typeHeader:SetHighlightFontObject(UI_FONT_NAME)
    typeHeader:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local values = GetUniqueValues("type")
            Viewer:ShowColumnFilterDropdown("type", self, values)
        else
            if Viewer.sortColumn == "type" then Viewer.sortAscending = not Viewer.sortAscending
            else Viewer.sortColumn = "type"; Viewer.sortAscending = true end
            Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
        end
    end)
    typeHeader:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    typeHeader:Hide() 

    local classHeader = CreateFrame("Button", nil, headerFrame)
    classHeader:SetSize(GRID_LAYOUT.CLASS_WIDTH, HEADER_HEIGHT)
    classHeader:SetPoint("LEFT", levelHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    classHeader:SetText("Class")
    classHeader:SetNormalFontObject(UI_FONT_NAME)
    classHeader:SetHighlightFontObject(UI_FONT_NAME)
    classHeader:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local values = GetUniqueValues("class")
            Viewer:ShowColumnFilterDropdown("class", self, values)
        else
            if Viewer.sortColumn == "class" then Viewer.sortAscending = not Viewer.sortAscending
            else Viewer.sortColumn = "class"; Viewer.sortAscending = true end
            Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
        end
    end)
    classHeader:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    classHeader:Hide() 

    local zoneHeader = CreateFrame("Button", nil, headerFrame)
    zoneHeader:SetSize(GRID_LAYOUT.ZONE_WIDTH, HEADER_HEIGHT)
    zoneHeader:SetPoint("LEFT", classHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    zoneHeader:SetText("Zone")
    zoneHeader:SetNormalFontObject(UI_FONT_NAME)
    zoneHeader:SetHighlightFontObject(UI_FONT_NAME)
    zoneHeader:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local values = GetUniqueValues("zone")
            Viewer:ShowColumnFilterDropdown("zone", self, values)
        else
            if Viewer.sortColumn == "zone" then Viewer.sortAscending = not Viewer.sortAscending
            else Viewer.sortColumn = "zone"; Viewer.sortAscending = true end
            Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
        end
    end)
    zoneHeader:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local foundByHeader = CreateFrame("Button", nil, headerFrame)
    foundByHeader:SetSize(GRID_LAYOUT.FOUND_BY_WIDTH, HEADER_HEIGHT)
    foundByHeader:SetPoint("LEFT", zoneHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    foundByHeader:SetText("Found By")
    foundByHeader:SetNormalFontObject(UI_FONT_NAME)
    foundByHeader:SetHighlightFontObject(UI_FONT_NAME)
    foundByHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "foundBy" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "foundBy"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)
    
    local vendorNameHeader = CreateFrame("Button", nil, headerFrame)
    vendorNameHeader:SetSize(GRID_LAYOUT.VENDOR_NAME_WIDTH_INLINE, HEADER_HEIGHT)
    vendorNameHeader:SetPoint("LEFT", 5, 0)
    vendorNameHeader:SetText("Vendor Name")
    vendorNameHeader:SetNormalFontObject(UI_FONT_NAME)
    vendorNameHeader:SetHighlightFontObject(UI_FONT_NAME)
    vendorNameHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "vendorName" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "vendorName"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)

    local inventoryHeader = headerFrame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    inventoryHeader:SetSize(GRID_LAYOUT.VENDOR_INVENTORY_WIDTH, HEADER_HEIGHT)
    inventoryHeader:SetPoint("LEFT", vendorNameHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    inventoryHeader:SetText("Inventory")
    
    local vendorPriceHeader = CreateFrame("Button", nil, headerFrame)
    vendorPriceHeader:SetSize(GRID_LAYOUT.VENDOR_PRICE_WIDTH, HEADER_HEIGHT)
    vendorPriceHeader:SetPoint("LEFT", inventoryHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    vendorPriceHeader:SetText("Price")
    vendorPriceHeader:SetNormalFontObject(UI_FONT_NAME)
    vendorPriceHeader:SetHighlightFontObject(UI_FONT_NAME)
    vendorPriceHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "price" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "price"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)

    local vendorTypeHeader = CreateFrame("Button", nil, headerFrame)
    vendorTypeHeader:SetSize(GRID_LAYOUT.VENDOR_TYPE_WIDTH, HEADER_HEIGHT)
    vendorTypeHeader:SetPoint("LEFT", vendorPriceHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    vendorTypeHeader:SetText("Type")
    vendorTypeHeader:SetNormalFontObject(UI_FONT_NAME)
    vendorTypeHeader:SetHighlightFontObject(UI_FONT_NAME)
    vendorTypeHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "vendorType" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "vendorType"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)

    local vendorZoneHeader = CreateFrame("Button", nil, headerFrame)
    vendorZoneHeader:SetSize(GRID_LAYOUT.VENDOR_ZONE_WIDTH, HEADER_HEIGHT)
    vendorZoneHeader:SetPoint("LEFT", vendorTypeHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    vendorZoneHeader:SetText("Zone")
    vendorZoneHeader:SetNormalFontObject(UI_FONT_NAME)
    vendorZoneHeader:SetHighlightFontObject(UI_FONT_NAME)
    vendorZoneHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "zone" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "zone"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)
    
    local vendorContinentHeader = CreateFrame("Button", nil, headerFrame)
    vendorContinentHeader:SetSize(GRID_LAYOUT.VENDOR_CONTINENT_WIDTH, HEADER_HEIGHT)
    vendorContinentHeader:SetPoint("LEFT", vendorZoneHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
    vendorContinentHeader:SetText("Continent")
    vendorContinentHeader:SetNormalFontObject(UI_FONT_NAME)
    vendorContinentHeader:SetHighlightFontObject(UI_FONT_NAME)
    vendorContinentHeader:SetScript("OnClick", function()
        if Viewer.sortColumn == "continent" then Viewer.sortAscending = not Viewer.sortAscending
        else Viewer.sortColumn = "continent"; Viewer.sortAscending = true end
        Viewer.currentPage = 1; Viewer:UpdateSortHeaders(); Viewer:RefreshData()
    end)
    
    local actionsLabel = headerFrame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    actionsLabel:SetPoint("RIGHT", -45, 0)
    actionsLabel:SetTextColor(0.4, 0.6, 1.0)
    actionsLabel:SetText("Actions")

    local clearAllBtn = CreateFrame("Button", nil, window)
    clearAllBtn:SetSize(70, 22)
    clearAllBtn:SetPoint("TOPRIGHT", window, "TOPRIGHT", -25, -47)
    clearAllBtn:SetFrameLevel(FRAME_LEVEL + 1)
    
    clearAllBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    clearAllBtn:SetBackdropColor(0.15, 0.15, 0.25, 0.8)
    clearAllBtn:SetBackdropBorderColor(0.3, 0.3, 0.5, 0.8)
    
    local cfs = clearAllBtn:CreateFontString(nil, "OVERLAY")
    cfs:SetFontObject(UI_FONT_NAME)
    cfs:SetTextColor(1, 0.4, 0.4)
    cfs:SetPoint("CENTER", 0, 1)
    clearAllBtn:SetFontString(cfs)
    
    clearAllBtn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.4, 0.4, 1) end)
    clearAllBtn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.5, 0.8) end)
    
    clearAllBtn:SetText("Clear")
    clearAllBtn:SetScript("OnClick", function()
        Viewer:ClearDiscoveriesFilters()
    end)

    self.refreshDataBtn = refreshDataBtn
    
    local reloadBtn = CreateFrame("Button", nil, additionalFiltersFrame, "BackdropTemplate")
    reloadBtn:SetSize(70, 22)
    reloadBtn:SetPoint("BOTTOMRIGHT", additionalFiltersFrame, "BOTTOMRIGHT", 80, -30)
    reloadBtn:SetFrameStrata(FRAME_STRATA)
    reloadBtn:SetFrameLevel(FRAME_LEVEL + 1)
    
    reloadBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    reloadBtn:SetBackdropColor(0.15, 0.15, 0.25, 0.8)
    reloadBtn:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.8)
    
    local rfs = reloadBtn:CreateFontString(nil, "OVERLAY")
    rfs:SetFontObject(UI_FONT_NAME)
    rfs:SetTextColor(1, 0.4, 0.4)
    rfs:SetPoint("CENTER", 0, 1)
    rfs:SetText("Reload")
    reloadBtn:SetFontString(rfs)
    
    reloadBtn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.4, 0.4, 1) end)
    reloadBtn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.8) end)

    reloadBtn:SetScript("OnClick", function() ReloadUI() end)
    reloadBtn:Hide()
    self.reloadBtn = reloadBtn

    local reloadText = additionalFiltersFrame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    reloadText:SetPoint("RIGHT", reloadBtn, "LEFT", -10, 0)
    reloadText:SetText("|cffff0000If Level, Slot, or Type are empty:|r")
    reloadText:Hide()
    self.reloadText = reloadText    

    local paginationFrame = CreateFrame("Frame", nil, window)
    paginationFrame:SetSize(WINDOW_WIDTH - 32, 32)
    paginationFrame:SetPoint("BOTTOM", 0, 20)
    paginationFrame:SetFrameStrata(FRAME_STRATA)
    paginationFrame:SetFrameLevel(FRAME_LEVEL + 1)

    paginationFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    paginationFrame:SetBackdropColor(0.06, 0.06, 0.10, 0.95)
    paginationFrame:SetBackdropBorderColor(0.20, 0.20, 0.28, 1)

    local pageInfo = paginationFrame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    pageInfo:SetPoint("CENTER", 10, 0)
    pageInfo:SetText("Page 1 of 1")

    local progressBar = CreateFrame("StatusBar", nil, paginationFrame)
    progressBar:SetPoint("TOPLEFT", paginationFrame, "TOPLEFT", 1, -1)
    progressBar:SetPoint("BOTTOMRIGHT", paginationFrame, "BOTTOMRIGHT", -1, 1)
    progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    progressBar:SetStatusBarColor(0.12, 0.20, 0.35, 0.5)
    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(0)
    progressBar:Hide()

    local barTexture = progressBar:GetStatusBarTexture()
    if barTexture then
        barTexture:SetDrawLayer("BACKGROUND", -1)
    end

    progressBar.targetValue = 0
    progressBar:SetScript("OnUpdate", function(self, elapsed)
        if not self.targetValue then return end
        local curr = self:GetValue()
        if math.abs(curr - self.targetValue) < 0.1 then
            self:SetValue(self.targetValue)
        else
            local newValue = curr + (self.targetValue - curr) * math.min(1, elapsed * 8)
            self:SetValue(newValue)
        end
    end)

    local function CreateFlatBtn(parent, label, width, anchorPoint, x, y)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, BUTTON_HEIGHT)
        if anchorPoint then btn:SetPoint(anchorPoint, x or 0, y or 0) end
        btn:SetFrameStrata(FRAME_STRATA)
        btn:SetFrameLevel(FRAME_LEVEL + 1)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(true)
        btn.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.bg:SetVertexColor(0.10, 0.10, 0.16, 0.85)
        btn.bgInner = btn:CreateTexture(nil, "ARTWORK")
        btn.bgInner:SetPoint("TOPLEFT", 1, -1)
        btn.bgInner:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.bgInner:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.92)
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        btn:SetHighlightTexture(hl)
        btn._label = btn:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
        btn._label:SetAllPoints(true)
        btn._label:SetText(label)
        btn._label:SetTextColor(0.78, 0.78, 0.85, 1)
        btn._label:SetJustifyH("CENTER")
        
        btn.GetFontString = function(self) return self._label end
        btn.SetText = function(self, text) self._label:SetText(text) end
        btn.GetText = function(self) return self._label:GetText() end
        btn:SetScript("OnEnter", function(self) self.bgInner:SetVertexColor(0.14, 0.14, 0.22, 0.95) end)
        btn:SetScript("OnLeave", function(self) self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.92) end)
        btn:SetScript("OnMouseDown", function(self) self.bgInner:SetVertexColor(0.10, 0.20, 0.35, 1) end)
        btn:SetScript("OnMouseUp", function(self) self.bgInner:SetVertexColor(0.06, 0.06, 0.10, 0.92) end)
        return btn
    end

    local prevBtn = CreateFlatBtn(paginationFrame, "Previous", 80, "LEFT", 5, 0)
    prevBtn:SetScript("OnClick", function()
        if self.currentPage > 1 then
            self.currentPage = self.currentPage - 1
            self:UpdatePagination()
            self:UpdateRows()
        end
    end)

    local nextBtn = CreateFlatBtn(paginationFrame, "Next", 80, "RIGHT", -10, 0)
    nextBtn:SetScript("OnClick", function()
        local totalPages = self:GetTotalPages()
        if self.currentPage < totalPages then
            self.currentPage = self.currentPage + 1
            self:UpdatePagination()
            self:UpdateRows()
        end
    end)

    local itemsLabel = paginationFrame:CreateFontString(nil, "OVERLAY", UI_FONT_NAME)
    itemsLabel:SetPoint("LEFT", prevBtn, "RIGHT", 20, 0)
    itemsLabel:SetText("Items per page:")

    local items25Btn = CreateFlatBtn(paginationFrame, "25", 30)
    self.items25Btn = items25Btn
    items25Btn:SetPoint("LEFT", itemsLabel, "RIGHT", 5, 0)
    items25Btn:SetScript("OnClick", function()
        local oldItemsPerPage = Viewer.itemsPerPage
        Viewer.itemsPerPage = 25
        local currentItemIndex = (Viewer.currentPage - 1) * oldItemsPerPage + 1
        Viewer.currentPage = math.ceil(currentItemIndex / Viewer.itemsPerPage)
        Viewer:UpdateItemsPerPageButtons()
        Viewer:UpdatePagination()
        Viewer:RefreshData()
    end)

    local items50Btn = CreateFlatBtn(paginationFrame, "50", 30)
    self.items50Btn = items50Btn
    items50Btn:SetPoint("LEFT", items25Btn, "RIGHT", 2, 0)
    items50Btn:SetScript("OnClick", function()
        local oldItemsPerPage = Viewer.itemsPerPage
        Viewer.itemsPerPage = 50
        local currentItemIndex = (Viewer.currentPage - 1) * oldItemsPerPage + 1
        Viewer.currentPage = math.ceil(currentItemIndex / Viewer.itemsPerPage)
        Viewer:UpdateItemsPerPageButtons()
        Viewer:UpdatePagination()
        Viewer:RefreshData()
    end)

    local items100Btn = CreateFlatBtn(paginationFrame, "100", 35)
    self.items100Btn = items100Btn
    items100Btn:SetPoint("LEFT", items50Btn, "RIGHT", 2, 0)
    items100Btn:SetScript("OnClick", function()
        local oldItemsPerPage = Viewer.itemsPerPage
        Viewer.itemsPerPage = 100
        local currentItemIndex = (Viewer.currentPage - 1) * oldItemsPerPage + 1
        Viewer.currentPage = math.ceil(currentItemIndex / Viewer.itemsPerPage)
        Viewer:UpdateItemsPerPageButtons()
        Viewer:UpdatePagination()
        Viewer:RefreshData()
    end)

    local items500Btn = CreateFlatBtn(paginationFrame, "500", 35)
    self.items500Btn = items500Btn
    items500Btn:SetPoint("LEFT", items100Btn, "RIGHT", 2, 0)
    items500Btn:SetScript("OnClick", function()
        local oldItemsPerPage = Viewer.itemsPerPage
        Viewer.itemsPerPage = 500
        local currentItemIndex = (Viewer.currentPage - 1) * oldItemsPerPage + 1
        Viewer.currentPage = math.ceil(currentItemIndex / Viewer.itemsPerPage)
        Viewer:UpdateItemsPerPageButtons()
        Viewer:UpdatePagination()
        Viewer:RefreshData()
    end)

    local itemsAllBtn = CreateFlatBtn(paginationFrame, "All", 35)
    self.itemsAllBtn = itemsAllBtn
    itemsAllBtn:SetPoint("LEFT", items500Btn, "RIGHT", 2, 0)
    itemsAllBtn:SetScript("OnClick", function()
        local oldItemsPerPage = Viewer.itemsPerPage
        Viewer.itemsPerPage = 99999
        local currentItemIndex = (Viewer.currentPage - 1) * oldItemsPerPage + 1
        Viewer.currentPage = math.ceil(currentItemIndex / Viewer.itemsPerPage)
        Viewer:UpdateItemsPerPageButtons()
        Viewer:UpdatePagination()
        Viewer:RefreshData()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "LootCollectorViewerScrollFrame", window, "FauxScrollFrameTemplate")
    scrollFrame:SetSize(WINDOW_WIDTH - 60, WINDOW_HEIGHT - 232) 
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetFrameLevel(FRAME_LEVEL + 1)
    scrollFrame:SetFrameStrata(FRAME_STRATA)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() Viewer:UpdateRows() end)
    end)
    window:SkinScrollBar(scrollFrame)
    
    self.window = window
    self.scrollFrame = scrollFrame
    self.equipmentBtn = equipmentBtn
    self.mysticBtn = mysticBtn
    self.bmvBtn = bmvBtn
    self.searchBox = searchBox
    self.minReqLevelBox = minReqLevelBox
    self.maxReqLevelBox = maxReqLevelBox
    self.searchClearBtn = clearBtn
    self.additionalFiltersFrame = additionalFiltersFrame
    self.filtersLabel = filtersLabel
    self.sourceFilterBtn = sourceFilterBtn
    self.qualityFilterBtn = qualityFilterBtn
    self.statsFilterBtn = statsFilterBtn
    self.favoritesFilterBtn = favoritesFilterBtn
    self.lootedFilterBtn = lootedFilterBtn
    self.nameHeader = nameHeader
    self.favHeader = favHeader
    self.levelHeader = levelHeader
    self.slotHeader = slotHeader
    self.typeHeader = typeHeader
    self.classHeader = classHeader
    self.zoneHeader = zoneHeader    
    self.foundByHeader = foundByHeader
    
    vendorNameHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.vendorNameHeader = vendorNameHeader    
    vendorNameHeader:Hide()
    
    vendorPriceHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.vendorPriceHeader = vendorPriceHeader
    vendorPriceHeader:Hide()
    
    vendorTypeHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.vendorTypeHeader = vendorTypeHeader
    vendorTypeHeader:Hide()
    
    inventoryHeader:SetTextColor(1, 0.82, 0)
    inventoryHeader:SetJustifyH("LEFT")
    self.inventoryHeader = inventoryHeader
    inventoryHeader:Hide()
    
    vendorZoneHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.vendorZoneHeader = vendorZoneHeader
    vendorZoneHeader:Hide()
    
    vendorContinentHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.vendorContinentHeader = vendorContinentHeader
    vendorContinentHeader:Hide()
    
    self.clearAllBtn = clearAllBtn
    self.actionsLabel = actionsLabel
    self.pageInfo = pageInfo
    self.progressBar = progressBar
    self.prevBtn = prevBtn
    self.nextBtn = nextBtn
    self.items25Btn = items25Btn    
    self.items50Btn = items50Btn
    self.items100Btn = items100Btn
    self.items500Btn = items500Btn
    self.itemsAllBtn = itemsAllBtn
    self.paginationFrame = paginationFrame
    self.duplicatesFilterBtn = duplicatesFilterBtn
    self.presetsFilterBtn = presetsFilterBtn
    self.vendorTypeFilterBtn = vendorTypeFilterBtn
    self.typeFilterBtn = typeFilterBtn
    self.slotsFilterBtn = slotsFilterBtn
    self.usableByFilterBtn = usableByFilterBtn
    self.lsFilterBtn = lsFilterBtn
    
    self.interactiveElements = {
        equipmentBtn, mysticBtn, bmvBtn,
        searchBox, sourceFilterBtn, qualityFilterBtn, statsFilterBtn, typeFilterBtn, lootedFilterBtn, duplicatesFilterBtn, presetsFilterBtn, vendorTypeFilterBtn, collectedMEFilterBtn, lsFilterBtn, fadeFilterBtn,
        nameHeader, levelHeader, slotHeader, typeHeader, classHeader, zoneHeader,  foundByHeader,
        vendorNameHeader, vendorPriceHeader, vendorZoneHeader, vendorContinentHeader, vendorTypeHeader,
        clearAllBtn, prevBtn, nextBtn, items25Btn, items50Btn, items100Btn, items500Btn, itemsAllBtn,
        slotsFilterBtn, usableByFilterBtn, favoritesFilterBtn
    }

    
    
    
    local splitter = CreateFrame("Button", "LootCollectorViewerSplitter", window)
    splitter:SetHeight(8)
    splitter:SetFrameStrata("HIGH")
    splitter:SetFrameLevel(window:GetFrameLevel() + 20)
    
    splitter.tex = splitter:CreateTexture(nil, "OVERLAY")
    splitter.tex:SetHeight(2)
    splitter.tex:SetPoint("LEFT", 5, 0)
    splitter.tex:SetPoint("RIGHT", -5, 0)
    splitter.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    splitter.tex:SetVertexColor(0.25, 0.3, 0.4, 0.6)
    
    splitter:SetScript("OnEnter", function(self)        
        SetCursor("Interface\\CURSOR\\UI-Cursor-Size.blp")
        self.tex:SetVertexColor(0.3, 0.6, 1.0, 1.0)
    end)
    splitter:SetScript("OnLeave", function(self)
        ResetCursor()
        self.tex:SetVertexColor(0.25, 0.3, 0.4, 0.6)
    end)
    
    splitter:SetMovable(true)
    splitter:RegisterForDrag("LeftButton")
    
    splitter:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", function(s)
            local _, cy = GetCursorPosition()
            local effScale = window:GetEffectiveScale()
            cy = cy / effScale
            
            local topY = Viewer.scrollFrame:GetTop() or (window:GetTop() - 100)
            local bottomY = paginationFrame:GetTop() or (window:GetBottom() + 40)
            local totalHeight = topY - bottomY
            
            if totalHeight > 50 then
                local cursorDist = topY - cy
                local ratio = cursorDist / totalHeight
                ratio = math.max(0.15, math.min(0.85, ratio))
                
                Viewer.splitRatio = ratio
                L.db.profile.viewer.splitRatio = ratio
                
                Viewer:UpdateLayout()
                Viewer:UpdateRows()
            end
        end)
    end)
    
    splitter:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        ResetCursor()
        if L.db and L.db.profile and L.db.profile.viewer then
            L.db.profile.viewer.splitRatio = Viewer.splitRatio
        end
    end)
    
    self.splitterBar = splitter
    splitter:Hide()

    self:CreateRows()

    self.currentFilter = "eq"
    self:UpdateFilterButtons()
    self:UpdateSortHeaders()
    self:UpdateItemsPerPageButtons()
    self:UpdateFilterButtonStates()
	
    window:SetScript("OnSizeChanged", function(self, width, height)
        if headerFrame then headerFrame:SetWidth(width - 40) end
        if paginationFrame then paginationFrame:SetWidth(width - 32) end
        
        Viewer:UpdateLayout()
        Viewer:CreateRows()

        local innerWidth = width - 60
        local staticEq = GRID_LAYOUT.FAV_WIDTH + GRID_LAYOUT.LEVEL_WIDTH + GRID_LAYOUT.SLOT_WIDTH + 
                         GRID_LAYOUT.TYPE_WIDTH + GRID_LAYOUT.ZONE_WIDTH + GRID_LAYOUT.FOUND_BY_WIDTH + 
                         (GRID_LAYOUT.COLUMN_SPACING * 6) + 162
        
        local currentNameWidth = math.max(GRID_LAYOUT.NAME_WIDTH, innerWidth - staticEq)
        local baseVendorNameWidth = Viewer.inlineVendorView and GRID_LAYOUT.VENDOR_NAME_WIDTH_INLINE or GRID_LAYOUT.VENDOR_NAME_WIDTH_SPLIT
        local currentVendorNameWidth = baseVendorNameWidth + (currentNameWidth - GRID_LAYOUT.NAME_WIDTH)

        if Viewer.nameHeader then Viewer.nameHeader:SetWidth(currentNameWidth) end
        if Viewer.vendorNameHeader then Viewer.vendorNameHeader:SetWidth(currentVendorNameWidth) end

        for _, row in ipairs(Viewer.rows) do
            row:SetWidth(innerWidth)
        end
        Viewer:UpdateRows()
    end)
    
    if pTime then L:ProfileStop("Scanner:ExtractClassToken", pTime) end
end

function Viewer:CreateRows(count)
    local pTime = L.ProfileStart and L:ProfileStart() 
    
    local innerWidth = self.window:GetWidth() - 60
    count = count or math.ceil(self:GetMainScrollHeight() / ROW_HEIGHT)

    
    
    local staticEq = GRID_LAYOUT.FAV_WIDTH + GRID_LAYOUT.LEVEL_WIDTH + GRID_LAYOUT.SLOT_WIDTH + 
                     GRID_LAYOUT.TYPE_WIDTH + GRID_LAYOUT.ZONE_WIDTH + GRID_LAYOUT.FOUND_BY_WIDTH + 
                     (GRID_LAYOUT.COLUMN_SPACING * 6) + 162
                     
    local currentNameWidth = math.max(GRID_LAYOUT.NAME_WIDTH, innerWidth - staticEq)
    local baseVendorNameWidth = self.inlineVendorView and GRID_LAYOUT.VENDOR_NAME_WIDTH_INLINE or GRID_LAYOUT.VENDOR_NAME_WIDTH_SPLIT
    local currentVendorNameWidth = baseVendorNameWidth + (currentNameWidth - GRID_LAYOUT.NAME_WIDTH)

    for i = 1, count do
        local row = self.rows[i]
        if not row then
            -- Named so /framestack can identify our frames when debugging
            -- stray visuals.
            row = CreateFrame("Frame", "LootCollectorViewerRow" .. i, self.scrollFrame:GetParent())
            row:SetHeight(ROW_HEIGHT)
            row:SetFrameLevel(self.scrollFrame:GetFrameLevel() + 1)
            row:SetFrameStrata(FRAME_STRATA)
            
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            
            row.rowBg = row:CreateTexture(nil, "ARTWORK", nil, -1)
            row.rowBg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
            row.rowBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
            row.rowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
            if i % 2 == 0 then
                row.rowBg:SetVertexColor(0.12, 0.14, 0.20, 0.65)
            else
                row.rowBg:SetVertexColor(0.06, 0.06, 0.10, 0.40)
            end
            row.isEvenRow = (i % 2 == 0)

            row.hoverTex = row:CreateTexture(nil, "ARTWORK", nil, 0)
            row.hoverTex:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
            row.hoverTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
            row.hoverTex:SetTexture("Interface\\Buttons\\WHITE8X8")
            row.hoverTex:SetVertexColor(0.20, 0.45, 0.80, 0.0)

            row.highlight = row:CreateTexture(nil, "OVERLAY")
            row.highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
            row.highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
            row.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.highlight:SetBlendMode("ADD")
            row.highlight:Hide()

            row.separatorLine = row:CreateTexture(nil, "OVERLAY")
            row.separatorLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -2)
            row.separatorLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
            row.separatorLine:SetHeight(1)
            row.separatorLine:SetTexture("Interface\\Buttons\\WHITE8X8")
            row.separatorLine:SetVertexColor(0.25, 0.28, 0.38, 0.7)  -- fine dark blue-grey separator line
            row.separatorLine:Hide()

            local nameFrame = CreateFrame("Frame", nil, row)
            nameFrame:SetSize(currentNameWidth, ROW_HEIGHT) 
            
            nameFrame:SetPoint("LEFT", row, "LEFT", 5, 0)
            nameFrame:EnableMouse(true)

            local iconFrame = CreateFrame("Frame", "LootCollectorViewerRowIcon" .. i, nameFrame)
            iconFrame:SetSize(20, 20)
            iconFrame:SetPoint("LEFT", 0, 0)
            iconFrame:SetFrameLevel(row:GetFrameLevel() + 10)
            row.iconFrame = iconFrame

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints(iconFrame)
            
            local rawSetDesaturated = iconTex.SetDesaturated
            iconTex.SetDesaturated = function(self, desaturated) rawSetDesaturated(self, false) end
            local rawSetVertexColor = iconTex.SetVertexColor
            iconTex.SetVertexColor = function(self, r, g, b, a) rawSetVertexColor(self, 1, 1, 1, 1) end
            local rawSetAlpha = iconTex.SetAlpha
            iconTex.SetAlpha = function(self, alpha) rawSetAlpha(self, 1.0) end

            row.iconTex = iconTex

            local nameText = nameFrame:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            nameText:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
            nameText:SetPoint("RIGHT", 0, 0)
            nameText:SetJustifyH("LEFT")

            nameFrame:SetScript("OnEnter", function(self)
                local parentRow = self:GetParent()
                if parentRow and parentRow.hoverTex then
                    parentRow.hoverTex:SetVertexColor(0.20, 0.40, 0.70, 0.12)
                end
                if self.discoveryData then
                    if self.discoveryData.isVendorItemRow then
                        local item = self.discoveryData.item
                        if item and item.link then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 20, 10)
                            GameTooltip:SetHyperlink(item.link)
                            GameTooltip:Show()
                            GameTooltip:SetFrameStrata("TOOLTIP") 
                        end
                    else
                        local d = self.discoveryData.discovery
                        local displayItemID = self.discoveryData.displayItemID
                        -- Vendor records carry negative pseudo item IDs which
                        -- SetHyperlink rejects ("Unknown link type").
                        if d and (tonumber(d.i) or 0) < 0 then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 20, 10)
                            GameTooltip:SetText(d.vendorName or "Special Vendor", 1, 0.82, 0)
                            if d.vendorItems and #d.vendorItems > 0 then
                                GameTooltip:AddLine(string.format("%d items for sale", #d.vendorItems), 0.8, 0.8, 0.8)
                            end
                            GameTooltip:Show()
                            GameTooltip:SetFrameStrata("TOOLTIP")
                            return
                        end
                        if displayItemID then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 20, 10)
                            -- Unreleased phase upgrades never resolve
                            -- ("Retrieving item information" forever); show
                            -- the BASE item instead when that happens.
                            local baseI = d and tonumber(d.i)
                            if not GetItemInfo(displayItemID) and baseI and baseI ~= displayItemID and GetItemInfo(baseI) then
                                GameTooltip:SetHyperlink("item:" .. baseI)
                                GameTooltip:AddLine("Upgrade data not available yet - showing base item.", 0.7, 0.7, 0.7, true)
                            else
                                GameTooltip:SetHyperlink("item:" .. displayItemID)
                            end
                            GameTooltip:Show()
                            GameTooltip:SetFrameStrata("TOOLTIP")
                        elseif d and d.il then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 20, 10)
                            GameTooltip:SetHyperlink(d.il)
                            GameTooltip:Show()
                            GameTooltip:SetFrameStrata("TOOLTIP") 
                        elseif d and d.i then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 20, 10)
                            GameTooltip:SetHyperlink("item:" .. d.i)
                            GameTooltip:Show()
                            GameTooltip:SetFrameStrata("TOOLTIP") 
                        end
                    end
                end
            end)

            nameFrame:SetScript("OnLeave", function(self)
                local parentRow = self:GetParent()
                if parentRow and parentRow.hoverTex then
                    parentRow.hoverTex:SetVertexColor(0.20, 0.40, 0.70, 0.0)
                end
                GameTooltip:Hide()
            end)	  

            nameFrame:SetScript("OnMouseUp", function(self, button)
                if not self.discoveryData then return end
                
                local guid = self.discoveryData.guid
                local db = L:GetDiscoveriesDB()
                local dbV = L:GetVendorsDB()
                local currentRecord = (db and db[guid]) or (dbV and dbV[guid])
                
                if not currentRecord then
                    print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                    Cache.discoveriesBuilt = false
                    Viewer:RefreshData()
                    return
                end
                
                self.discoveryData.discovery = currentRecord
                local data = self.discoveryData
                local r  = self:GetParent()
                Viewer:SetSelectedRow(r)

                local isVendorView = (Viewer.currentFilter == "bmv")
                if isVendorView and data.isVendor and button == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() then
                    if Viewer.inlineVendorView then
                        Viewer.expandedVendors = Viewer.expandedVendors or {}
                        if Viewer.expandedVendors[data.guid] then
                            Viewer.expandedVendors[data.guid] = nil
                        else
                            Viewer.expandedVendors[data.guid] = true
                        end
                        Cache.lastFilterState = nil
                        Viewer:RefreshData()
                    else
                        if Viewer.ShowVendorInventoryForDiscovery and data.discovery then
                            Viewer:ShowVendorInventoryForDiscovery(data.discovery)
                        end
                    end
                    return
                end

                if IsShiftKeyDown() and data then
                    local Map = L:GetModule("Map", true)
                    if Map and Map.IsChatEditBoxOpen and Map:IsChatEditBoxOpen() then
                        local overrideLink = nil
                        local displayItemID = data.displayItemID
                        if displayItemID and tonumber(displayItemID) and tonumber(displayItemID) > 0 then
                            local _, link = GetItemInfo(displayItemID)
                            overrideLink = link or ("item:" .. displayItemID)
                        end
                        if Map.LinkDiscoveryItemToChat then
                            Map:LinkDiscoveryItemToChat(data.discovery, overrideLink)
                        end
                    else
                        Viewer:ShowOnMap(data)
                    end
                    return
                end

                local isCtrlDown = IsControlKeyDown()

                if button == "LeftButton" then
                    if isCtrlDown then self:LinkItemToChat() end
                elseif button == "RightButton" then
                    if isCtrlDown then
                        local zoneName = GetLocalizedZoneName(data.discovery)
                        local coords = ""
                        if data.discovery.xy then                        
                            coords = string.format("%.2f, %.2f", (data.discovery.xy.x or 0) * 100, (data.discovery.xy.y or 0) * 100)
                        end
                        local msg = string.format("%s @ %s (%s)", data.discovery.il or "Item", zoneName, coords)
                        if ChatFrame1EditBox:IsVisible() then
                            ChatFrame1EditBox:Insert(msg)
                        else
                            ChatFrame_OpenChat(msg)
                        end
                    else
                        self:ShowContextMenu()
                    end
                end
            end)

            nameFrame:SetScript("OnMouseDown", function(self, button)
                if button == "RightButton" then
                    local x, y = GetCursorPosition()
                    self.mouseX = x
                    self.mouseY = y
                end
            end)

            local favBtn = CreateFrame("Button", nil, row)
            favBtn:SetSize(GRID_LAYOUT.FAV_WIDTH, ROW_HEIGHT)
            favBtn:SetPoint("LEFT", nameFrame, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            local favIcon = favBtn:CreateTexture(nil, "ARTWORK")
            favIcon:SetSize(16, 16)
            favIcon:SetPoint("CENTER", 0, 0)
            favIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
            row.favIcon = favIcon
            row.favBtn = favBtn

            favBtn:SetScript("OnClick", function(self)
                local data = row.discoveryData
                if data and data.discovery and data.discovery.i then
                    local itemId = data.discovery.i
                    
                    local guid = data.guid
                    local db = L:GetDiscoveriesDB()
                    if not (db and db[guid]) then
                        print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                        Cache.discoveriesBuilt = false
                        Viewer:RefreshData()
                        return
                    end

                    PlaySound("igMainMenuOptionCheckBoxOn")
                    local favorites = L:GetFavoritesDB()
                    if favorites[itemId] then
                        favorites[itemId] = nil
                        favIcon:SetDesaturated(true)
                        favIcon:SetVertexColor(0.5, 0.5, 0.5, 0.5)
                    else
                        favorites[itemId] = true
                        favIcon:SetDesaturated(false)
                        favIcon:SetVertexColor(1, 1, 1, 1)
                    end
                    if Viewer.favoritesFilterState then
                        -- FIXED: the filter-state hash cannot see favorites
                        -- CONTENT changes (only the toggle), so without this
                        -- invalidation the cached filtered list was reused
                        -- and the just-unfavorited row stayed visible.
                        Cache.filteredResults = {}
                        Cache.lastFilterState = nil
                        Viewer:RefreshData()
                    end
                end
            end)

            local levelText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            levelText:SetPoint("LEFT", favBtn, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            levelText:SetSize(GRID_LAYOUT.LEVEL_WIDTH, ROW_HEIGHT)
            levelText:SetJustifyH("LEFT")

            local slotText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            slotText:SetPoint("LEFT", levelText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            slotText:SetSize(GRID_LAYOUT.SLOT_WIDTH, ROW_HEIGHT)
            slotText:SetJustifyH("LEFT")
            slotText:Hide()

            local typeText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            typeText:SetPoint("LEFT", slotText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            typeText:SetSize(GRID_LAYOUT.TYPE_WIDTH, ROW_HEIGHT)
            typeText:SetJustifyH("LEFT")
            typeText:Hide()

            local classText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            classText:SetPoint("LEFT", levelText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            classText:SetSize(GRID_LAYOUT.CLASS_WIDTH, ROW_HEIGHT)
            classText:SetJustifyH("LEFT")
            classText:Hide()

            local zoneText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            zoneText:SetPoint("LEFT", typeText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            zoneText:SetSize(GRID_LAYOUT.ZONE_WIDTH, ROW_HEIGHT)
            zoneText:SetJustifyH("LEFT")

            local foundByFrame = CreateFrame("Frame", nil, row)
            foundByFrame:SetSize(GRID_LAYOUT.FOUND_BY_WIDTH, ROW_HEIGHT)
            foundByFrame:SetPoint("LEFT", zoneText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            foundByFrame:EnableMouse(true)

            local foundByText = foundByFrame:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            foundByText:SetPoint("LEFT", 2, 0)
            foundByText:SetSize(GRID_LAYOUT.FOUND_BY_WIDTH - 4, ROW_HEIGHT)
            foundByText:SetJustifyH("LEFT")

            foundByFrame:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and self.discoveryData then
                    local x, y = GetCursorPosition()
                    self.mouseX = x
                    self.mouseY = y
                    self:ShowFoundByContextMenu()
                end
            end)

            foundByFrame.ShowFoundByContextMenu = function(self)
                if not self.discoveryData or not self.discoveryData.discovery.fp then return end
                local playerName = self.discoveryData.discovery.fp
                local buttons = {
                    { text = "Delete all from " .. playerName, onClick = function() Viewer:ConfirmDeleteAllFromPlayer(playerName) end },
                    { text = "Block & Purge " .. playerName, onClick = function() Viewer:BlockAndPurgePlayer(playerName) end }
                }
                CreateContextMenu(self, "Player: " .. playerName, buttons)
            end

            
            
            
            local vendorNameText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            
            vendorNameText:SetPoint("LEFT", row, "LEFT", 5, 0)
            vendorNameText:SetSize(currentVendorNameWidth, ROW_HEIGHT) 
            vendorNameText:SetJustifyH("LEFT")
            vendorNameText:Hide()

            local vendorNameFrame = CreateFrame("Frame", nil, row)
            -- FIXED: this frame used to be two-point-anchored to the
            -- vendorNameText FontString AND then hit with SetWidth in
            -- UpdateRows -- an over-constrained rect that went stale while
            -- dragging the window (the vendor name column visually stayed
            -- behind at the old screen position and snapped back when the
            -- drag ended). Use a conventional single anchor + explicit size.
            vendorNameFrame:SetPoint("LEFT", row, "LEFT", 38, 0)
            vendorNameFrame:SetSize(GRID_LAYOUT.VENDOR_NAME_WIDTH_INLINE, ROW_HEIGHT)
            vendorNameFrame:EnableMouse(true)
            vendorNameFrame:Hide()

            local vendorIconFrame = CreateFrame("Frame", "LootCollectorViewerRowVendorIcon" .. i, row)
            vendorIconFrame:SetSize(20, 20)

            vendorIconFrame:SetPoint("LEFT", row, "LEFT", 5, 0)
            vendorIconFrame:SetFrameLevel(row:GetFrameLevel() + 10)
            row.vendorIconFrame = vendorIconFrame

            local vendorIconTex = vendorIconFrame:CreateTexture(nil, "ARTWORK")
            -- Explicit size instead of SetAllPoints: guarantees a square
            -- 20x20 icon regardless of any frame-rect weirdness (icons were
            -- rendering vertically stretched on the Vendors tab).
            vendorIconTex:SetPoint("CENTER", vendorIconFrame, "CENTER", 0, 0)
            vendorIconTex:SetSize(20, 20)
            vendorIconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local rawSetDesaturated = vendorIconTex.SetDesaturated
            vendorIconTex.SetDesaturated = function(self, desaturated) rawSetDesaturated(self, false) end
            local rawSetVertexColor = vendorIconTex.SetVertexColor
            vendorIconTex.SetVertexColor = function(self, r, g, b, a) rawSetVertexColor(self, 1, 1, 1, 1) end
            local rawSetAlpha = vendorIconTex.SetAlpha
            vendorIconTex.SetAlpha = function(self, alpha) rawSetAlpha(self, 1.0) end
            row.vendorIconTex = vendorIconTex

            local vendorPriceText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            vendorPriceText:SetSize(GRID_LAYOUT.VENDOR_PRICE_WIDTH, ROW_HEIGHT)
            vendorPriceText:SetJustifyH("LEFT")
            vendorPriceText:Hide()

            local vendorTypeText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            vendorTypeText:SetSize(GRID_LAYOUT.VENDOR_TYPE_WIDTH, ROW_HEIGHT)
            vendorTypeText:SetJustifyH("LEFT")
            vendorTypeText:Hide()

            local inventoryFrame = CreateFrame("Button", nil, row)
            inventoryFrame:SetSize(GRID_LAYOUT.VENDOR_INVENTORY_WIDTH, ROW_HEIGHT)
            inventoryFrame:EnableMouse(true)
            inventoryFrame:Hide()

            local inventoryText = inventoryFrame:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            inventoryText:SetAllPoints(true)
            inventoryText:SetJustifyH("LEFT")
            inventoryText:SetText("|cff00ff00View Items...|r")

            local vendorZoneText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            vendorZoneText:SetSize(GRID_LAYOUT.VENDOR_ZONE_WIDTH, ROW_HEIGHT)
            vendorZoneText:SetJustifyH("LEFT")
            vendorZoneText:Hide()

            local vendorContinentText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
            vendorContinentText:SetSize(GRID_LAYOUT.VENDOR_CONTINENT_WIDTH, ROW_HEIGHT)
            vendorContinentText:SetJustifyH("LEFT")
            vendorContinentText:Hide()

            
            local function OnVendorInteraction(self, button)
                if not self.discoveryData then return end
                
                local guid = self.discoveryData.guid
                local dbV = L:GetVendorsDB()
                local currentRecord = dbV and dbV[guid]
                
                if not currentRecord then
                    print("|cffff7f00LootCollector:|r This vendor no longer exists. Refreshing list...")
                    Cache.discoveriesBuilt = false
                    Viewer:RefreshData()
                    return
                end
                
                self.discoveryData.discovery = currentRecord
                local data = self.discoveryData
                local r  = self:GetParent()
                Viewer:SetSelectedRow(r)

                local isVendorView = (Viewer.currentFilter == "bmv")
                if isVendorView and data.isVendor and button == "LeftButton"
                   and not IsControlKeyDown() then
                    if Viewer.inlineVendorView then
                        Viewer.expandedVendors = Viewer.expandedVendors or {}
                        if Viewer.expandedVendors[data.guid] then
                            Viewer.expandedVendors[data.guid] = nil
                        else
                            Viewer.expandedVendors[data.guid] = true
                        end
                        Cache.lastFilterState = nil
                        Viewer:RefreshData()
                    else
                        if Viewer.ShowVendorInventoryForDiscovery and data.discovery then
                            Viewer:ShowVendorInventoryForDiscovery(data.discovery)
                        end
                    end
                end
            end

            vendorNameFrame:SetScript("OnMouseUp", OnVendorInteraction)
            inventoryFrame:SetScript("OnMouseUp", OnVendorInteraction)

            inventoryFrame:SetScript("OnEnter", function(self)
                if self.discoveryData and self.discoveryData.isVendor and self.discoveryData.discovery.vendorItems then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Inventory", 1, 1, 0)
                    for _, item in ipairs(self.discoveryData.discovery.vendorItems) do
                        GameTooltip:AddLine(item.link)
                    end
                    GameTooltip:Show()
                    GameTooltip:SetFrameStrata("TOOLTIP") 
                end
            end)
            inventoryFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

            
            local function CreateFlatActionBtn(parent, label, r, g, b, tooltipText, anchorTo, anchorPoint)
                local btn = CreateFrame("Button", nil, parent)
                btn:SetSize(18, 16)
                if anchorTo then
                    btn:SetPoint("RIGHT", anchorTo, "LEFT", -3, 0)
                end
                btn.bg = btn:CreateTexture(nil, "BACKGROUND")
                btn.bg:SetAllPoints(true)
                btn.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
                btn.bg:SetVertexColor(r * 0.30, g * 0.30, b * 0.30, 0.85)
                btn.border = btn:CreateTexture(nil, "BORDER")
                btn.border:SetAllPoints(true)
                btn.border:SetTexture("Interface\\Buttons\\WHITE8X8")
                btn.border:SetVertexColor(r * 0.70, g * 0.70, b * 0.70, 0.80)
                btn.border:SetAlpha(0)
                btn.bgInner = btn:CreateTexture(nil, "ARTWORK")
                btn.bgInner:SetPoint("TOPLEFT", 1, -1)
                btn.bgInner:SetPoint("BOTTOMRIGHT", -1, 1)
                btn.bgInner:SetTexture("Interface\\Buttons\\WHITE8X8")
                btn.bgInner:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 0.90)
                btn.label = btn:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
                btn.label:SetAllPoints(true)
                btn.label:SetText(label)
                btn.label:SetTextColor(r, g, b, 1)
                btn.label:SetJustifyH("CENTER")

                btn:SetScript("OnEnter", function(self)
                    self.bg:SetVertexColor(r * 0.55, g * 0.55, b * 0.55, 1)
                    self.bgInner:SetVertexColor(r * 0.30, g * 0.30, b * 0.30, 1)
                    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                    GameTooltip:SetText(tooltipText)
                    GameTooltip:Show()
                    GameTooltip:SetFrameStrata("TOOLTIP")
                end)
                btn:SetScript("OnLeave", function(self)
                    self.bg:SetVertexColor(r * 0.30, g * 0.30, b * 0.30, 0.85)
                    self.bgInner:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 0.90)
                    GameTooltip:Hide()
                end)
                btn:SetScript("OnMouseDown", function(self) self.label:SetPoint("TOPLEFT", 1, -2) end)
                btn:SetScript("OnMouseUp", function(self) self.label:SetPoint("TOPLEFT", 0, 0) end)
                return btn
            end

            local deleteBtn = CreateFlatActionBtn(row, "D", 1.0, 0.3, 0.3, "Delete", nil, nil)
            deleteBtn:SetPoint("RIGHT", -5, 0)
            deleteBtn:SetScript("OnClick", function(self)
                Viewer:SetSelectedRow(self:GetParent())
                local r = self:GetParent()
                if r.discoveryData then 
                    local guid = r.discoveryData.guid
                    local db = L:GetDiscoveriesDB()
                    local dbV = L:GetVendorsDB()
                    if not (db and db[guid]) and not (dbV and dbV[guid]) then
                        print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                        Cache.discoveriesBuilt = false
                        Viewer:RefreshData()
                        return
                    end

                    r.deleteBtn:SetEnabled(false)
                    r.navBtn:SetEnabled(false)
                    r.showBtn:SetEnabled(false)
                    r.lootedBtn:SetEnabled(false)
                    r.unlootedBtn:SetEnabled(false)
                    r:SetAlpha(0.4)
                    
                    Viewer:ConfirmDelete(r.discoveryData) 
                end
            end)

            local unlootedBtn = CreateFlatActionBtn(row, "U", 1.0, 0.65, 0.1, "Mark as Unlooted", deleteBtn, nil)
            unlootedBtn:SetScript("OnClick", function(self)
                Viewer:SetSelectedRow(self:GetParent())
                local r = self:GetParent()
                if r.discoveryData then 
                    local guid = r.discoveryData.guid
                    local db = L:GetDiscoveriesDB()
                    if not (db and db[guid]) then
                        print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                        Cache.discoveriesBuilt = false
                        Viewer:RefreshData()
                        return
                    end
                    Viewer:ToggleLootedState(guid, r.discoveryData) 
                end
            end)

            local lootedBtn = CreateFlatActionBtn(row, "L", 0.6, 1.0, 0.2, "Mark as Looted", unlootedBtn, nil)
            lootedBtn:SetScript("OnClick", function(self)
                Viewer:SetSelectedRow(self:GetParent())
                local r = self:GetParent()
                if r.discoveryData then 
                    local guid = r.discoveryData.guid
                    local db = L:GetDiscoveriesDB()
                    if not (db and db[guid]) then
                        print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                        Cache.discoveriesBuilt = false
                        Viewer:RefreshData()
                        return
                    end
                    Viewer:ToggleLootedState(guid, r.discoveryData) 
                end
            end)

            local navBtn = CreateFlatActionBtn(row, "N", 0.2, 0.8, 1.0, "Navigate", lootedBtn, nil)
            navBtn:SetScript("OnClick", function(self)
                Viewer:SetSelectedRow(self:GetParent())
                local r = self:GetParent()
                if r.discoveryData then
                    local guid = r.discoveryData.guid
                    local db = L:GetDiscoveriesDB()
                    local dbV = L:GetVendorsDB()
                    local currentRecord = (db and db[guid]) or (dbV and dbV[guid])
                    if not currentRecord then
                        print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                        Cache.discoveriesBuilt = false
                        Viewer:RefreshData()
                        return
                    end
                    local Arrow = L:GetModule("Arrow", true)
                    if Arrow and Arrow.NavigateTo then Arrow:NavigateTo(currentRecord) end
                end
            end)

            local showBtn = CreateFlatActionBtn(row, "S", 0.5, 0.5, 1.0, "Show on Map", navBtn, nil)
            showBtn:SetScript("OnClick", function(self)
                Viewer:SetSelectedRow(self:GetParent())
                local r = self:GetParent()
                if r.discoveryData then 
                    local guid = r.discoveryData.guid
                    local db = L:GetDiscoveriesDB()
                    local dbV = L:GetVendorsDB()
                    local currentRecord = (db and db[guid]) or (dbV and dbV[guid])
                    if not currentRecord then
                        print("|cffff7f00LootCollector:|r This discovery no longer exists. Refreshing list...")
                        Cache.discoveriesBuilt = false
                        Viewer:RefreshData()
                        return
                    end
                    Viewer:ShowOnMap(currentRecord) 
                end
            end)

            nameFrame.ShowContextMenu = function(self)
                if not self.discoveryData then return end
                local isLooted = Viewer:IsLootedByChar(self.discoveryData.guid)
                local buttons = {
                    { text = "Show", onClick = function() Viewer:ShowOnMap(self.discoveryData) end },
                    {
                        text = "Show to... (map ping)",
                        onClick = function()
                            local Map = L:GetModule("Map", true)
                            local d = self.discoveryData and self.discoveryData.discovery
                            if Map and Map.OpenShowToDialog and d then
                                Map:OpenShowToDialog(d)
                            end
                        end
                    },
                    { text = isLooted and "Set as unlooted" or "Set as looted", onClick = function() Viewer:ToggleLootedState(self.discoveryData.guid, self.discoveryData) end },
                    { text = "Delete", onClick = function() Viewer:ConfirmDelete(self.discoveryData) end },
                }
                CreateContextMenu(self, self.discoveryData.itemName or "Unknown Item", buttons)
            end

            nameFrame.LinkItemToChat = function(self)
                if not self.discoveryData then return end
                local Map = L:GetModule("Map", true)
                local d = self.discoveryData.discovery
                local overrideLink = nil
                local displayItemID = self.discoveryData.displayItemID
                if displayItemID and tonumber(displayItemID) and tonumber(displayItemID) > 0 then
                    local _, link = GetItemInfo(displayItemID)
                    overrideLink = link or ("item:" .. displayItemID)
                end
                if Map and Map.LinkDiscoveryItemToChat then
                    Map:LinkDiscoveryItemToChat(d, overrideLink)
                end
            end
            
            row.nameFrame      = nameFrame
            row.nameText       = nameText
            row.levelText      = levelText
            row.slotText       = slotText
            row.typeText       = typeText
            row.classText      = classText
            row.zoneText       = zoneText
            row.foundByFrame   = foundByFrame
            row.foundByText    = foundByText

            row.vendorNameText  = vendorNameText
            row.vendorNameFrame = vendorNameFrame
            row.vendorPriceText = vendorPriceText
            row.vendorTypeText  = vendorTypeText
            row.vendorZoneText  = vendorZoneText
            row.vendorContinentText = vendorContinentText
            row.inventoryFrame  = inventoryFrame
            row.inventoryText   = inventoryText

            row.deleteBtn      = deleteBtn
            row.unlootedBtn    = unlootedBtn
            row.lootedBtn      = lootedBtn
            row.navBtn         = navBtn
            row.showBtn        = showBtn

            self.rows[i] = row
        end
        
        row:SetSize(innerWidth, ROW_HEIGHT)
    end
    
    if pTime then L:ProfileStop("Viewer:CreateRows", pTime) end 
end

function Viewer:UpdateFilterButtons()
    
    if self.equipmentBtn and self.equipmentBtn.SetActive then self.equipmentBtn:SetActive(false) end
    if self.mysticBtn    and self.mysticBtn.SetActive    then self.mysticBtn:SetActive(false) end
    if self.bmvBtn       and self.bmvBtn.SetActive       then self.bmvBtn:SetActive(false) end

    
    if self.currentFilter == "eq" and self.equipmentBtn and self.equipmentBtn.SetActive then
        self.equipmentBtn:SetActive(true)
    elseif self.currentFilter == "ms" and self.mysticBtn and self.mysticBtn.SetActive then
        self.mysticBtn:SetActive(true)
    elseif self.currentFilter == "bmv" and self.bmvBtn and self.bmvBtn.SetActive then
        self.bmvBtn:SetActive(true)
    end
end

function Viewer:UpdateSortHeaders()
    local pTime = L.ProfileStart and L:ProfileStart() 

    local function setButtonTextColor(button, r, g, b)
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetTextColor(r, g, b)
        end
    end

    local isEqView = (self.currentFilter == "eq" or self.currentFilter == "msv")
    local isMsView = (self.currentFilter == "ms")
    local isVendorView = (self.currentFilter == "bmv")

    self.nameHeader:Hide(); self.favHeader:Hide(); self.slotHeader:Hide(); self.typeHeader:Hide(); self.classHeader:Hide()
    self.zoneHeader:Hide(); self.levelHeader:Hide(); self.foundByHeader:Hide()
    
    self.vendorNameHeader:Hide()
    if self.vendorPriceHeader then self.vendorPriceHeader:Hide() end
    self.vendorTypeHeader:Hide()
    self.vendorZoneHeader:Hide()
    self.vendorContinentHeader:Hide()
    self.inventoryHeader:Hide()
    
    local lastHeader = nil

    if isVendorView then
        self.vendorNameHeader:Show()
        self.vendorTypeHeader:Show()
        self.vendorZoneHeader:Show()
        self.vendorContinentHeader:Show()
        
        if self.inlineVendorView then
            self.inventoryHeader:Show()
            if self.vendorPriceHeader then self.vendorPriceHeader:Show() end
        end
        
        self.vendorNameHeader:ClearAllPoints()
        self.vendorNameHeader:SetPoint("LEFT", 5, 0)
        lastHeader = self.vendorNameHeader

        if self.inlineVendorView then
            self.inventoryHeader:ClearAllPoints()
            self.inventoryHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            lastHeader = self.inventoryHeader

            if self.vendorPriceHeader then
                self.vendorPriceHeader:ClearAllPoints()
                self.vendorPriceHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
                lastHeader = self.vendorPriceHeader
            end
        end

        self.vendorTypeHeader:ClearAllPoints()
        self.vendorTypeHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        lastHeader = self.vendorTypeHeader

        self.vendorZoneHeader:ClearAllPoints()
        self.vendorZoneHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        lastHeader = self.vendorZoneHeader

        self.vendorContinentHeader:ClearAllPoints()
        self.vendorContinentHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        
        local sortIndicator = self.sortAscending and " \124TInterface\\Buttons\\UI-SortArrow-Up:12:12:0:0\124t" or " \124TInterface\\Buttons\\UI-SortArrow-Down:12:12:0:0\124t"
        local sortColor = {0.2, 0.8, 1}
        local defaultColor = {1, 1, 1}

        setButtonTextColor(self.vendorNameHeader, self.sortColumn == "vendorName" and sortColor[1] or defaultColor[1], self.sortColumn == "vendorName" and sortColor[2] or defaultColor[2], self.sortColumn == "vendorName" and sortColor[3] or defaultColor[3])
        if self.inlineVendorView and self.vendorPriceHeader then
            setButtonTextColor(self.vendorPriceHeader, self.sortColumn == "price" and sortColor[1] or defaultColor[1], self.sortColumn == "price" and sortColor[2] or defaultColor[2], self.sortColumn == "price" and sortColor[3] or defaultColor[3])
        end
        setButtonTextColor(self.vendorTypeHeader, self.sortColumn == "vendorType" and sortColor[1] or defaultColor[1], self.sortColumn == "vendorType" and sortColor[2] or defaultColor[2], self.sortColumn == "vendorType" and sortColor[3] or defaultColor[3])
        setButtonTextColor(self.vendorZoneHeader, self.sortColumn == "zone" and sortColor[1] or defaultColor[1], self.sortColumn == "zone" and sortColor[2] or defaultColor[2], self.sortColumn == "zone" and sortColor[3] or defaultColor[3])
        
        self.vendorNameHeader:SetText(self.sortColumn == "vendorName" and "Vendor Name" .. sortIndicator or "Vendor Name")
        if self.inlineVendorView and self.vendorPriceHeader then
            self.vendorPriceHeader:SetText(self.sortColumn == "price" and "Price" .. sortIndicator or "Price")
        end
        self.vendorTypeHeader:SetText(self.sortColumn == "vendorType" and "Type" .. sortIndicator or "Type")
        self.vendorZoneHeader:SetText(self.sortColumn == "zone" and "Zone" .. sortIndicator or "Zone")

    else 
        self.nameHeader:Show(); self.favHeader:Show(); self.levelHeader:Show(); self.zoneHeader:Show(); self.foundByHeader:Show()
        
        self.nameHeader:ClearAllPoints()
        self.nameHeader:SetPoint("LEFT", 5, 0)
        lastHeader = self.nameHeader
        
        self.favHeader:ClearAllPoints()
        self.favHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        lastHeader = self.favHeader

        self.levelHeader:ClearAllPoints()
        self.levelHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        lastHeader = self.levelHeader

        if isEqView then
            self.slotHeader:Show()
            self.typeHeader:Show()

            self.slotHeader:ClearAllPoints()
            self.slotHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            lastHeader = self.slotHeader

            self.typeHeader:ClearAllPoints()
            self.typeHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            lastHeader = self.typeHeader
        elseif isMsView then
            self.classHeader:Show()

            self.classHeader:ClearAllPoints()
            self.classHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
            lastHeader = self.classHeader
        end
        
        self.zoneHeader:ClearAllPoints()
        self.zoneHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        lastHeader = self.zoneHeader

        self.foundByHeader:ClearAllPoints()
        self.foundByHeader:SetPoint("LEFT", lastHeader, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
        
        local sortIndicator = self.sortAscending and " ↑" or " ↓"
        local headerMap = { name=self.nameHeader, level=self.levelHeader, slot=self.slotHeader, type=self.typeHeader, class=self.classHeader, zone=self.zoneHeader,  foundBy=self.foundByHeader }
        local headerTextMap = { name="Name", level="Level", slot="Slot", type="Type", class="Class", zone="Zone", foundBy="Found By" }
        
        for col, header in pairs(headerMap) do
            if header:IsShown() then
                local isSorted = (col == self.sortColumn)
                local isFiltered = false
                if (self.currentFilter == "eq" and self.columnFilters.eq[col] and next(self.columnFilters.eq[col])) or
                   (self.currentFilter == "ms" and self.columnFilters.ms[col] and next(self.columnFilters.ms[col])) or
                   (self.columnFilters[col] and next(self.columnFilters[col])) then
                    isFiltered = true
                end

                if isSorted then
                    setButtonTextColor(header, 0.2, 0.8, 1) 
                elseif isFiltered then
                    setButtonTextColor(header, 1, 0.8, 0.2) 
                else
                    setButtonTextColor(header, 1, 1, 1) 
                end

                local text = headerTextMap[col]
                if isSorted then text = text .. sortIndicator end
                if isFiltered then text = text .. " [F]" end
                header:SetText(text)
            end
        end
    end
    
    if pTime then L:ProfileStop("Viewer:UpdateSortHeaders", pTime) end 
end

function Viewer:UpdatePagination()
    local totalPages = self:GetTotalPages()
    local totalItems = self.totalItems

    if self.pageInfo then
        if Cache.discoveriesBuilding then
            local total = self._cacheBuildQueue and #self._cacheBuildQueue or 0
            local processed = self._cacheQueueCursor or 1
            local progress = 0
            if total > 0 then
                progress = (processed / total) * 100
            end
            self.pageInfo:SetText(string.format("Loading Database: %d / %d (%d%%)", processed, total, math.floor(progress)))
            
            if self.progressBar then
                if not self.progressBar:IsShown() then
                    self.progressBar:SetValue(0)
                    self.progressBar.targetValue = 0
                    self.progressBar:Show()
                end
                self.progressBar:SetStatusBarColor(0.12, 0.20, 0.35, 0.5)
                self.progressBar.targetValue = progress
            end
        else
            local Core = L:GetModule("Core", true)
            local cacheQueue = Core and L.db and L.db.global and L.db.global.cacheQueue
            local currentQueueSize = cacheQueue and #cacheQueue or 0
            local isCachingActive = currentQueueSize > 0 and not L:IsPaused() and L.db.profile.autoCache
            
            if isCachingActive then
                if not self.cacheQueueMax or self.cacheQueueMax < currentQueueSize then
                    self.cacheQueueMax = currentQueueSize
                end
                local cachedCount = self.cacheQueueMax - currentQueueSize
                local progress = 0
                if self.cacheQueueMax > 0 then
                    progress = (cachedCount / self.cacheQueueMax) * 100
                end
                -- Tell the user WHAT is being cached. Classify a SAMPLE of
                -- the queue (not just the head) so the label doesn't
                -- flicker between kinds when base items and phase upgrades
                -- are interleaved.
                local nUpg, nWF = 0, 0
                for qi = 1, math.min(40, currentQueueSize) do
                    local qid = tonumber(cacheQueue[qi])
                    if qid then
                        if L.GetBaseItemID and L:GetBaseItemID(qid) ~= qid then
                            nUpg = nUpg + 1
                        elseif L.IsWorldforgedListItem and L:IsWorldforgedListItem(qid) then
                            nWF = nWF + 1
                        end
                    end
                end
                local kindText = "Item Data"
                if nUpg > 0 and nWF > 0 then
                    kindText = "Items & Upgrades"
                elseif nUpg > 0 then
                    kindText = "Phase Upgrades"
                elseif nWF > 0 then
                    kindText = "Worldforged Items"
                end
                self.pageInfo:SetText(string.format("Caching %s: %d / %d (%d%%) - server lookups, safe to play", kindText, cachedCount, self.cacheQueueMax, math.floor(progress)))
                
                if self.progressBar then
                    if not self.progressBar:IsShown() then
                        self.progressBar:SetValue(0)
                        self.progressBar.targetValue = 0
                        self.progressBar:Show()
                    end
                    self.progressBar:SetStatusBarColor(0.12, 0.35, 0.20, 0.5)
                    self.progressBar.targetValue = progress
                end
            else
                self.cacheQueueMax = 0
                self.pageInfo:SetText(string.format("Page %d of %d (%d total items)", self.currentPage, totalPages, totalItems))
                if self.progressBar then
                    self.progressBar:Hide()
                end
            end
        end
    end

    if self.prevBtn then
        self.prevBtn:SetEnabled(not Cache.discoveriesBuilding and self.currentPage > 1)
    end
    if self.nextBtn then
        self.nextBtn:SetEnabled(not Cache.discoveriesBuilding and self.currentPage < totalPages)
    end
end

function Viewer:UpdateItemsPerPageButtons()
    local function setButtonTextColor(button, r, g, b)
        local fontString = button and button:GetFontString()
        if fontString then
            fontString:SetTextColor(r, g, b)
        end
    end

    if self.items25Btn then setButtonTextColor(self.items25Btn, 0.8, 0.8, 0.8) end
    if self.items50Btn then setButtonTextColor(self.items50Btn, 0.8, 0.8, 0.8) end
    if self.items100Btn then setButtonTextColor(self.items100Btn, 0.8, 0.8, 0.8) end
    if self.items500Btn then setButtonTextColor(self.items500Btn, 0.8, 0.8, 0.8) end
    if self.itemsAllBtn then setButtonTextColor(self.itemsAllBtn, 0.8, 0.8, 0.8) end

    if self.itemsPerPage == 25 and self.items25Btn then
        setButtonTextColor(self.items25Btn, 1, 0.82, 0)
    elseif self.itemsPerPage == 50 and self.items50Btn then
        setButtonTextColor(self.items50Btn, 1, 0.82, 0)
    elseif self.itemsPerPage == 100 and self.items100Btn then
        setButtonTextColor(self.items100Btn, 1, 0.82, 0)
    elseif self.itemsPerPage == 500 and self.items500Btn then
        setButtonTextColor(self.items500Btn, 1, 0.82, 0)
    elseif self.itemsPerPage >= 99999 and self.itemsAllBtn then
        setButtonTextColor(self.itemsAllBtn, 1, 0.82, 0)
    end
end

function Viewer:UpdateRows()
    local pTime = L.ProfileStart and L:ProfileStart() 

    local discoveries = self:GetPaginatedDiscoveries()
    local numDiscoveries = #discoveries
    
    local visibleRows = math.ceil(self:GetMainScrollHeight() / ROW_HEIGHT)
    if #self.rows < visibleRows then
        self:CreateRows(visibleRows)
    end

    self:UpdatePagination()

    local isEqView = (self.currentFilter == "eq" or self.currentFilter == "msv")
    local isMsView = (self.currentFilter == "ms")
    local isVendorView = (self.currentFilter == "bmv")
    
    local isLoading = Cache.discoveriesBuilding

    FauxScrollFrame_Update(self.scrollFrame, numDiscoveries, visibleRows, ROW_HEIGHT)
    
    if self.scrollFrame.ScrollBar and self.scrollFrame.ScrollBar.ScrollUpButton then
        self.scrollFrame.ScrollBar.ScrollUpButton:SetFrameStrata(FRAME_STRATA)
        self.scrollFrame.ScrollBar.ScrollUpButton:SetFrameLevel(FRAME_LEVEL)
    end
    if self.scrollFrame.ScrollBar and self.scrollFrame.ScrollBar.ScrollDownButton then
        self.scrollFrame.ScrollBar.ScrollDownButton:SetFrameStrata(FRAME_STRATA)
        self.scrollFrame.ScrollBar.ScrollDownButton:SetFrameLevel(FRAME_LEVEL)
    end

    local innerWidth = self.window:GetWidth() - 60
    local staticEq = GRID_LAYOUT.FAV_WIDTH + GRID_LAYOUT.LEVEL_WIDTH + GRID_LAYOUT.SLOT_WIDTH + 
                     GRID_LAYOUT.TYPE_WIDTH + GRID_LAYOUT.ZONE_WIDTH + GRID_LAYOUT.FOUND_BY_WIDTH + 
                     (GRID_LAYOUT.COLUMN_SPACING * 6) + 162
                     
    local currentNameWidth = math.max(GRID_LAYOUT.NAME_WIDTH, innerWidth - staticEq)
    local baseVendorNameWidth = self.inlineVendorView and GRID_LAYOUT.VENDOR_NAME_WIDTH_INLINE or GRID_LAYOUT.VENDOR_NAME_WIDTH_SPLIT
    local currentVendorNameWidth = baseVendorNameWidth + (currentNameWidth - GRID_LAYOUT.NAME_WIDTH)

    for i = 1, #self.rows do
        local row = self.rows[i]
        
        if i > visibleRows then
            row:Hide()
        else
            local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
            local data = discoveries[i + offset]

            if data then
                row:SetAlpha(1.0) 
                
                local discovery = data.discovery
                row.discoveryData = data
                row.nameFrame.discoveryData       = data
                row.foundByFrame.discoveryData    = data
                row.vendorNameFrame.discoveryData = data
                row.inventoryFrame.discoveryData  = data

                local isVendorItem = data.isVendorItemRow

                row.nameFrame:SetShown(not isVendorView and not isVendorItem)
                row.levelText:SetShown(not isVendorView and not isVendorItem)
                row.zoneText:SetShown((isEqView or isMsView) and not isVendorItem)
                row.foundByFrame:SetShown((isEqView or isMsView) and not isVendorItem)
                row.slotText:SetShown(isEqView and not isVendorItem)
                row.typeText:SetShown(isEqView and not isVendorItem)
                row.classText:SetShown(isMsView and not isVendorItem)
                
                row.vendorNameText:SetShown(isVendorView and not isVendorItem)
                row.vendorNameFrame:SetShown(isVendorView and not isVendorItem)
                row.vendorPriceText:SetShown(isVendorView)
                row.vendorTypeText:SetShown(isVendorView and not isVendorItem)
                row.vendorZoneText:SetShown(isVendorView and not isVendorItem)
                row.vendorContinentText:SetShown(isVendorView and not isVendorItem)
                row.inventoryFrame:SetShown(isVendorView and not isVendorItem and self.inlineVendorView)

                if self.selectedRow == row then
                    row.highlight:Show()
                else
                    row.highlight:Hide()
                end

                if row.separatorLine then
                    row.separatorLine:Hide()
                end
                
                if isVendorView then

                    row.vendorNameText:SetWidth(currentVendorNameWidth)
                    row.vendorNameFrame:SetSize(currentVendorNameWidth, ROW_HEIGHT)
                    
                    
                    
                    local currentX = 5 + currentVendorNameWidth + GRID_LAYOUT.COLUMN_SPACING
                    
                    if self.inlineVendorView then
                        row.inventoryFrame:ClearAllPoints()
                        row.inventoryFrame:SetPoint("LEFT", row, "LEFT", currentX, 0)
                        currentX = currentX + GRID_LAYOUT.VENDOR_INVENTORY_WIDTH + GRID_LAYOUT.COLUMN_SPACING
                        
                        row.vendorPriceText:ClearAllPoints()
                        row.vendorPriceText:SetPoint("LEFT", row, "LEFT", currentX, 0)
                        currentX = currentX + GRID_LAYOUT.VENDOR_PRICE_WIDTH + GRID_LAYOUT.COLUMN_SPACING
                    end
                    
                    row.vendorTypeText:ClearAllPoints()
                    row.vendorTypeText:SetPoint("LEFT", row, "LEFT", currentX, 0)
                    currentX = currentX + GRID_LAYOUT.VENDOR_TYPE_WIDTH + GRID_LAYOUT.COLUMN_SPACING
                    
                    row.vendorZoneText:ClearAllPoints()
                    row.vendorZoneText:SetPoint("LEFT", row, "LEFT", currentX, 0)
                    currentX = currentX + GRID_LAYOUT.VENDOR_ZONE_WIDTH + GRID_LAYOUT.COLUMN_SPACING
                    
                    row.vendorContinentText:ClearAllPoints()
                    row.vendorContinentText:SetPoint("LEFT", row, "LEFT", currentX, 0)
                end
                
                if isVendorItem then
                    if row.toggleText then row.toggleText:Hide() end
                    if row.vendorIconTex then row.vendorIconTex:Hide() end
                    if row.vendorIconFrame then row.vendorIconFrame:Hide() end
                    
                    local icon = data.item.icon or (data.item.itemID and GetItemIcon(data.item.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
                    row.iconTex:SetTexture(icon)
                    row.iconTex:SetAlpha(1.0)
                    row.iconTex:SetVertexColor(1, 1, 1, 1)
                    row.iconTex:SetDesaturated(false)
                    row.iconTex:Show()
                    
                    row:SetAlpha(1.0)
                    row.nameFrame:SetShown(true)
                    row.nameText:SetText(data.item.link or data.item.name)
                    row.nameText:SetAlpha(1.0)
                    row.nameText:SetTextColor(1, 1, 1, 1)
                    row.nameFrame:ClearAllPoints()
                    
                    row.nameFrame:SetPoint("LEFT", row, "LEFT", 20, 0)
                    
                    row.nameFrame:SetWidth(currentVendorNameWidth)
                    row.nameText:SetWidth(currentVendorNameWidth)
                    row.nameText:ClearAllPoints()
                    row.nameText:SetPoint("LEFT", row.iconFrame or row.iconTex, "RIGHT", 4, 0)
                    row.nameText:SetPoint("RIGHT", 0, 0)
                    
                    row.vendorPriceText:SetText(data.item.price and data.item.price > 0 and GetCoinTextureString(data.item.price) or "")
                    row.vendorPriceText:SetAlpha(1.0)
                    
                    row.deleteBtn:Hide()
                    row.navBtn:Hide()
                    row.showBtn:Hide()
                    row.unlootedBtn:Hide()
                    row.lootedBtn:Hide()
                    
                    if row.favBtn then row.favBtn:Hide() end

                elseif isVendorView then
                    row:SetAlpha(1.0)
                    
                    local vType = discovery.vendorType or (discovery.g and discovery.g:find("MS-", 1, true) and "MS") or (discovery.g and discovery.g:find("EX-", 1, true) and "EX") or (discovery.g and discovery.g:find("RING-", 1, true) and "RING") or "BM"
                    local icon
                    if vType == "MS" then
                        icon = "Interface\\Icons\\INV_Scroll_03"
                    else
                        icon = discovery.il and GetItemIcon(discovery.il) or nil
                        if not icon and discovery.i then icon = GetItemIcon(discovery.i) end
                        if not icon then
                            if vType == "EX" then
                                icon = "Interface\\Icons\\INV_Ascend_Gems_2"
                            elseif vType == "RING" then
                                icon = "Interface\\Icons\\inv_misc_diamondring2"
                            else
                                icon = "Interface\\Icons\\ability_priest_darkness"
                            end
                        end
                    end

                    if icon then
                        row.vendorIconTex:SetTexture(icon)
                        row.vendorIconTex:SetAlpha(1.0)
                        row.vendorIconTex:SetVertexColor(1, 1, 1, 1)
                        row.vendorIconTex:SetDesaturated(false)
                        if row.vendorIconFrame then
                            row.vendorIconFrame:ClearAllPoints()
                            
                            row.vendorIconFrame:SetPoint("LEFT", row, "LEFT", 16, 0)
                            row.vendorIconFrame:Show()
                        else
                            row.vendorIconTex:ClearAllPoints()
                            
                            row.vendorIconTex:SetPoint("LEFT", row, "LEFT", 16, 0)
                        end
                        row.vendorIconTex:Show()
                        row.vendorNameText:ClearAllPoints()

                        row.vendorNameText:SetPoint("LEFT", row, "LEFT", 38, 0)
                        row.vendorNameFrame:ClearAllPoints()
                        row.vendorNameFrame:SetPoint("LEFT", row, "LEFT", 38, 0)
                    else
                        row.vendorIconTex:Hide()
                        if row.vendorIconFrame then row.vendorIconFrame:Hide() end
                        row.vendorNameText:ClearAllPoints()

                        row.vendorNameText:SetPoint("LEFT", row, "LEFT", 16, 0)
                        row.vendorNameFrame:ClearAllPoints()
                        row.vendorNameFrame:SetPoint("LEFT", row, "LEFT", 16, 0)
                    end
                    
                    if not row.toggleText then
                        row.toggleText = row:CreateFontString(nil, "OVERLAY", ROW_FONT_NAME)
                        row.toggleText:SetJustifyH("LEFT")
                    end

                    if self.inlineVendorView then
                        row.toggleText:Show()
                        local toggle = (Viewer.expandedVendors and Viewer.expandedVendors[data.guid]) and "-" or "+"
                        row.toggleText:SetText(toggle)
                        
                        row.toggleText:SetPoint("LEFT", row, "LEFT", 4, 0)
                    else
                        row.toggleText:Hide()
                    end
                    
                    row.vendorNameText:SetText(discovery.vendorName or "Unknown")
                    row.vendorNameText:SetTextColor(1, 0.82, 0)
                    row.vendorPriceText:SetText("")
                    
                    local typeText = discovery.vendorSubname or ""
                    if typeText == "" then
                        if discovery.vendorType == "BM" then typeText = "Blackmarket Artisan Supplies"
                        elseif discovery.vendorType == "EX" then typeText = "Exquisite Collectables"
                        elseif discovery.vendorType == "RING" then typeText = "Ring Vendor"
                        elseif discovery.vendorType == "MS" then typeText = "Mystic Enchants"
                        end
                    end
                    row.vendorTypeText:SetText(typeText)
                    
                    row.vendorZoneText:SetText(GetLocalizedZoneName(discovery))
                    local continentNames = { [1] = "Kalimdor", [2] = "Eastern Kingdoms", [3] = "Outland", [4] = "Northrend" }
                    row.vendorContinentText:SetText(discovery.c and continentNames[discovery.c] or "Unknown")
                    local invCount = (discovery.vendorItems and #discovery.vendorItems) or 0
                    row.inventoryText:SetText(string.format("(%d items)", invCount))
                    
                    if row.favBtn then row.favBtn:Hide() end
                else
                    if row.toggleText then row.toggleText:Hide() end
                    if row.vendorIconTex then row.vendorIconTex:Hide() end
                    if row.vendorIconFrame then row.vendorIconFrame:Hide() end
                    
                    row.nameFrame:SetWidth(currentNameWidth)
                    row.nameText:SetWidth(currentNameWidth)
                    
                    local isLooted = self:IsLootedByChar(data.guid)
                    local alpha = (not isLooted) and 1.0 or 0.5
                    local itemName = data.itemName
                    if not itemName or itemName:find("Unknown Item", 1, true) or (not data.itemType and not data.isMystic) then
                        local itemID = data.displayItemID or data.discovery.i
                        local name, link, quality, itemLevelVal, minLevel, itemTypeVal, itemSubTypeVal, _, equipLocVal = GetItemInfo(itemID)
                        if name and name ~= "" then
                            local Scanner = L:GetModule("Scanner", true)
                            local itemData = Scanner and Scanner:GetItemData(itemID, link or itemID) or {}
                            local isMystic = IsMysticScroll(name)
                            local isWorldforged = itemData.isWF or false
                            
                            local characterClass = ""
                            local classToken = itemData.classToken
                            if classToken then
                                characterClass = _G.LOCALIZED_CLASS_NAMES_MALE[classToken] or _G.LOCALIZED_CLASS_NAMES_FEMALE[classToken] or classToken
                            end

                            local finalMinLevel = itemData.reqLevel or minLevel or 0
                            
                            itemName = name
                            data.itemName = name
                            data.isMystic = isMystic
                            data.isWorldforged = data.isNew and true or isWorldforged
                            data.itemType = itemTypeVal
                            data.itemSubType = itemSubTypeVal
                            data.equipLoc = equipLocVal
                            data.characterClass = characterClass
                            data.itemLevel = itemLevelVal
                            data.minLevel = finalMinLevel
                            data.sortName = name
                            data.sortClass = characterClass or ""
                            data.sortType = itemSubTypeVal or ""
                            data.sortSlot = equipLocVal and _G[equipLocVal] or ""
                            -- Healed data can change filtering (e.g. CoA
                            -- relic hiding) and sorting; refilter soon.
                            Viewer:ScheduleFilterInvalidation()
                        elseif not data._prioCached then
                            -- Visible but uncached: jump this item to the
                            -- FRONT of the lookup queue instead of waiting
                            -- behind thousands of background upgrades.
                            data._prioCached = true
                            local CoreM = L:GetModule("Core", true)
                            if CoreM and CoreM.QueueItemForCachingPriority then
                                CoreM:QueueItemForCachingPriority(itemID)
                            end
                        end
                    end
                    
                    local r, g, b = GetColorForDiscovery(discovery, data.displayItemID or discovery.i)
                    itemName = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, itemName)
                    
                    local selectedPhase = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.worldforgedPhase or 0
                    if selectedPhase > 0 and data.displayItemID and data.discovery.i and data.displayItemID ~= data.discovery.i then
                        itemName = itemName .. " |cff00ff00▲|r"
                    end
                    if data.isNew then
                        itemName = itemName .. " |cffff7f00[NEW]|r"
                    end
                    local status = discovery.s
                    if status == STATUS_FADING then
                        itemName = itemName .. " |cffff7f00[FADING]|r"
                    elseif status == STATUS_STALE then
                        itemName = itemName .. " |cff9d9d9d[STALE]|r"
                    end
                    
                    local icon = data.displayItemID and GetItemIcon(data.displayItemID) or nil
                    if not icon then icon = data.discovery.il and GetItemIcon(data.discovery.il) or nil end
                    if not icon and data.discovery.i then icon = GetItemIcon(data.discovery.i) end
                    if icon then
                        row.iconTex:SetTexture(icon)
                        row.iconTex:SetAlpha(1.0)
                        row.iconTex:SetVertexColor(1, 1, 1, 1)
                        row.iconTex:SetDesaturated(false)
                        row.iconTex:Show()
                    else
                        row.iconTex:Hide()
                    end
                    
                    row.nameFrame:ClearAllPoints()
                    row.nameFrame:SetPoint("LEFT", 5, 0)
                    row.nameText:ClearAllPoints()
                    row.nameText:SetPoint("LEFT", row.iconFrame or row.iconTex, "RIGHT", 4, 0)
                    row.nameText:SetPoint("RIGHT", 0, 0)
                    row.nameText:SetText(itemName)
                    row.nameText:SetAlpha(alpha)

                    local lastElement = row.levelText
                    
                    if isEqView then
                        row.slotText:SetText(data.equipLoc and _G[data.equipLoc] or "")
                        row.slotText:SetAlpha(alpha)
                        row.typeText:SetText(data.itemSubType or "")
                        row.typeText:SetAlpha(alpha)
                        
                        row.zoneText:ClearAllPoints()
                        row.zoneText:SetPoint("LEFT", row.typeText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
                        lastElement = row.typeText
                    elseif isMsView then
                        local classDisplay = ""
                        if data.cl and data.cl ~= "cl" then
                            local classToken = CLASS_ABBREVIATIONS_REVERSE[data.cl]
                            if classToken then
                                classDisplay = (_G.LOCALIZED_CLASS_NAMES_MALE[classToken] or _G.LOCALIZED_CLASS_NAMES_FEMALE[classToken] or "")
                            end
                        end
                        if classDisplay == "" then classDisplay = data.characterClass or "" end
                        row.classText:SetText(classDisplay)
                        row.classText:SetAlpha(alpha)
                        
                        row.zoneText:ClearAllPoints()
                        row.zoneText:SetPoint("LEFT", row.classText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
                        lastElement = row.classText
                    end
                    
                    if lastElement ~= row.levelText then
                         row.zoneText:SetPoint("LEFT", lastElement, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
                    else 
                         row.zoneText:SetPoint("LEFT", row.levelText, "RIGHT", GRID_LAYOUT.COLUMN_SPACING, 0)
                    end

                    if data.isUndiscovered then
                        row.zoneText:SetText("|cff888888Unknown|r")
                        row.levelText:SetText("")
                        row.foundByText:SetText("|cff888888Undiscovered|r")
                    else
                        row.zoneText:SetText(GetLocalizedZoneName(discovery))
                        local levelTextVal = data.minLevel or 0
                        row.levelText:SetText(levelTextVal > 0 and tostring(levelTextVal) or "")
                        row.foundByText:SetText(discovery.fp or "Unknown")
                    end
                    row.zoneText:SetAlpha(alpha)
                    row.levelText:SetAlpha(alpha)
                    row.foundByText:SetAlpha(alpha)
                    
                    if row.favIcon then
                        row.favBtn:Show()
                        if discovery.i and L:GetFavoritesDB()[discovery.i] then
                            row.favIcon:SetDesaturated(false)
                            row.favIcon:SetVertexColor(1, 1, 1, 1)
                        else
                            row.favIcon:SetDesaturated(true)
                            row.favIcon:SetVertexColor(0.5, 0.5, 0.5, 0.5)
                        end
                    end
                end
                
                local isLooted = self:IsLootedByChar(data.guid)
                local isUndiscovered = data.isUndiscovered
                row.lootedBtn:SetEnabled(not isVendorView and not isLooted and not isLoading and not isUndiscovered)
                row.unlootedBtn:SetEnabled(not isVendorView and isLooted and not isLoading and not isUndiscovered)
                row.lootedBtn:SetShown(not isVendorView)
                row.unlootedBtn:SetShown(not isVendorView)
                row.lootedBtn:SetAlpha((isLooted and not isLoading and not isUndiscovered) and 1.0 or 0.2)
                row.unlootedBtn:SetAlpha((not isLooted and not isLoading and not isUndiscovered) and 1.0 or 0.2)
                
                row.deleteBtn:SetEnabled(not isLoading and not isUndiscovered)
                row.navBtn:SetEnabled(not isLoading and not isUndiscovered)
                row.showBtn:SetEnabled(not isLoading and not isUndiscovered)
                row.nameFrame:EnableMouse(not isLoading)
                row.deleteBtn:SetAlpha(isUndiscovered and 0.2 or 1.0)
                row.navBtn:SetAlpha(isUndiscovered and 0.2 or 1.0)
                row.showBtn:SetAlpha(isUndiscovered and 0.2 or 1.0)
                if not isVendorItem then
                    row.deleteBtn:Show()
                    row.navBtn:Show()
                    row.showBtn:Show()
                end
                row:Show()
            else
                row:Hide()
                row.discoveryData = nil
                row.nameFrame.discoveryData = nil
                row.foundByFrame.discoveryData = nil
                if row.highlight then row.highlight:Hide() end
                if row.bg then row.bg:Hide() end
                row.deleteBtn:Hide()
                row.navBtn:Hide()
                row.showBtn:Hide()
                row.lootedBtn:Hide()
                row.unlootedBtn:Hide()
            end
        end
    end

    local shownCount = 0
    for i = 1, #self.rows do
        local row = self.rows[i]
        if row:IsShown() then
            shownCount = shownCount + 1
            if shownCount % 2 == 0 then
                row.rowBg:SetVertexColor(0.12, 0.14, 0.20, 0.65)
            else
                row.rowBg:SetVertexColor(0.06, 0.06, 0.10, 0.40)
            end
        end
    end

    self:UpdateEmptyState(self.totalItems or 0)

    if pTime then L:ProfileStop("Viewer:UpdateRows", pTime) end 
end

function Viewer:PrewarmCache()
    if Cache.discoveriesBuilt or Cache.discoveriesBuilding then
        VDebug("PrewarmCache: skipped (built=" .. tostring(Cache.discoveriesBuilt) .. ", building=" .. tostring(Cache.discoveriesBuilding) .. ")")
        return
    end

    VDebug("PrewarmCache: starting async cache build in background")
    self:UpdateAllDiscoveriesCache(function()
        VDebug("PrewarmCache: async cache build complete (discoveries=" .. tostring(#Cache.discoveries) .. ")")
    end)
end

function Viewer:InvalidateFilterCache()
    Cache.filteredResults = {}
    Cache.lastFilterState = nil
    _filterHashDirty = true
end

-- Debounced filter invalidation + refresh. Used when row data heals in
-- place (item data arriving from the server): healed fields can change
-- filtering -- e.g. a healed row turning out to be a Libram that CoA
-- realms must hide -- but the filter-state hash doesn't change, so the
-- cached filtered list would otherwise keep serving the stale row set.
function Viewer:ScheduleFilterInvalidation()
    if self._invalidateTimer then return end
    self._invalidateTimer = C_Timer.After(0.4, function()
        Viewer._invalidateTimer = nil
        Cache.filteredResults = {}
        Cache.lastFilterState = nil
        _filterHashDirty = true
        if Viewer.window and Viewer.window:IsShown() then
            Viewer:RefreshData()
        end
    end)
end

function Viewer:RefreshData()
local pTime = L.ProfileStart and L:ProfileStart() 
    local t0 = time()
    VDebug("RefreshData: start, cacheBuilt=" .. tostring(Cache.discoveriesBuilt) ..
        ", building=" .. tostring(Cache.discoveriesBuilding))
    if not self.window or not self.window:IsShown() then return end

    self:UpdateFilterButtonStates()
	self:UpdateLayout()

    local now = time()
    local dataHasChanged = HasDataChanged()
    
    
    local shouldRebuildCache = false
    if not Cache.discoveriesBuilt or dataHasChanged then
        shouldRebuildCache = true
    end
    
    VDebug("RefreshData: dataHasChanged=" .. tostring(dataHasChanged) ..
        ", shouldRebuild=" .. tostring(shouldRebuildCache))

    if shouldRebuildCache and not Cache.discoveriesBuilding then
        VDebug("RefreshData: rebuilding discovery cache (chunked)")
        -- UpdateAllDiscoveriesCacheSync refuses to run while discoveriesBuilt
        -- is true. When we get here because the data changed (count drift),
        -- clear the flag so the rebuild actually happens instead of silently
        -- keeping stale rows.
        Cache.discoveriesBuilt = false
        self:UpdateAllDiscoveriesCacheSync(function()
            VDebug("RefreshData callback: async cache build complete, running GetFilteredDiscoveries + UpdateRows")
            local t1 = time()
            self:GetFilteredDiscoveries() 
            self:UpdateRows()
            VDebug("RefreshData callback: GetFilteredDiscoveries+UpdateRows took " ..
                tostring(time() - t1) .. "s")
        end)
    elseif Cache.discoveriesBuilt then
        VDebug("RefreshData: cache already built, running GetFilteredDiscoveries + UpdateRows")
        
        local t1 = time()
        self:GetFilteredDiscoveries()
        self:UpdateRows()
        VDebug("RefreshData: GetFilteredDiscoveries+UpdateRows took " ..
            tostring(time() - t1) .. "s")
    else
        VDebug("RefreshData: cache neither built nor rebuilding, nothing to do")
    end
    VDebug("RefreshData: end, total elapsed=" .. tostring(time() - t0) .. "s")
    if pTime then L:ProfileStop("Viewer:RefreshData", pTime) end 
end

function Viewer:IsLootedByChar(guid)
    if not guid or not (L.db and L.db.char and L.db.char.looted) then return false end
    return L.db.char.looted[guid] and true or false
end

function Viewer:ToggleLootedState(guid, discoveryData)
    if not guid or not (L.db and L.db.char) then return false end

    local isCurrentlyLooted = self:IsLootedByChar(guid)

    if isCurrentlyLooted then
        if L.UnmarkLooted then L:UnmarkLooted(guid) else
            L.db.char.looted = L.db.char.looted or {}
            L.db.char.looted[guid] = nil
        end
        print(string.format("|cff00ff00LootCollector:|r Marked '%s' as unlooted.", discoveryData.itemName or "Unknown Item"))
    else
        if L.MarkLooted then L:MarkLooted(guid) else
            L.db.char.looted = L.db.char.looted or {}
            L.db.char.looted[guid] = time()
        end
        print(string.format("|cff00ff00LootCollector:|r Marked '%s' as looted.", discoveryData.itemName or "Unknown Item"))
    end

    local Map = L:GetModule("Map", true)
    if Map then
        Map.cacheIsDirty = true 
        if Map.Update and WorldMapFrame and WorldMapFrame:IsShown() then Map:Update() end
        if Map.UpdateMinimap then Map:UpdateMinimap() end
    end

    self:RefreshData()
    return not isCurrentlyLooted 
end

function Viewer:ClearCaches()
    clearAllTimers()

    local cacheKeys = keys(Cache)
    for _, key in ipairs(cacheKeys) do
        if key == "discoveries" then Cache[key] = {}
        elseif key == "discoveriesBuilt" or key == "discoveriesBuilding" then Cache[key] = false
        elseif key == "uniqueValuesValid" then Cache[key] = false
        elseif key == "uniqueValues" then Cache[key] = { slot = {}, type = {}, class = {}, zone = {} }
        elseif key == "uniqueValuesContext" then Cache[key] = {}
        elseif key == "filteredResults" then Cache[key] = {}
        elseif key == "lastFilterState" then Cache[key] = nil
        elseif type(Cache[key]) == "table" then Cache[key] = {}
        end
    end

    local defaultFilters = {
        eq = { slot = {}, type = {}, class = {} },
        ms = { class = {} },
        zone = {},
        source = {},
        quality = {},
        looted = {},
        vendorType = {},
        duplicates = false 
    }
    self.columnFilters = copy(defaultFilters)

    Cache.duplicateItems = {}
    Cache.lastDiscoveryCount = nil
    L.itemInfoCache = {}
    Cache._cleanupRequired = true
    
    self.searchTerm = ""
    self.minReqLevel = nil
    self.maxReqLevel = nil
    self.lastSeenSortState = "off"
    self.lootedFilterState = nil
    self.collectedMEFilterState = nil
    self.favoritesFilterState = nil
    
    if self.minReqLevelBox then self.minReqLevelBox:SetText("") end
    if self.maxReqLevelBox then self.maxReqLevelBox:SetText("") end    
end

function Viewer:OnDisable()
    clearAllTimers()
    self:ClearCaches()

    if self.window then
        self.window:Hide()
        self.window:SetScript("OnShow", nil)
        self.window:SetScript("OnHide", nil)
        self.window:SetScript("OnDragStart", nil)
        self.window:SetScript("OnDragStop", nil)
    end

    if self.contextMenu then
        self.contextMenu:Hide()
        self.contextMenu = nil
    end

    if self.filterDropdown then
        self.filterDropdown:Hide()
        self.filterDropdown = nil
    end

    if self.autocompleteDropdown then
        self.autocompleteDropdown:Hide()
        self.autocompleteDropdown = nil
    end

    if self.mapCleanupFrame then
        self.mapCleanupFrame:UnregisterAllEvents()
        self.mapCleanupFrame:SetScript("OnEvent", nil)
        self.mapCleanupFrame = nil
    end

    if localClassScanTip then localClassScanTip:Hide() end
    if localWorldforgedScanTip then localWorldforgedScanTip:Hide() end

    scanQueue = {}
    scanCursor = 0
    scanProgressCallback = nil

    self.window = nil
    self.scrollFrame = nil
    self.rows = {}
    self.currentFilter = "eq"
    self.searchTerm = ""
    self.sortColumn = "name"
    self.sortAscending = true    
    self.pendingMapAreaID = nil
    self.currentPage = 1
    self.totalItems = 0
    self.lastSeenSortState = "off"
end

function Viewer:AddDiscoveryToCache(guid, discovery)
    if not guid or type(discovery) ~= "table" then return false end
    if not Cache.discoveriesBuilt or Cache.discoveriesBuilding then return false end

    local isVendor = (discovery.vendorType ~= nil) or (discovery.vendorName ~= nil)
    local row = {}
    if not FillDiscoveryRow(row, guid, discovery, {
        isVendor = isVendor,
        isUndiscovered = false,
        allowDBPurge = false,
    }) then
        return false
    end

    Cache.discoveriesByGuid = Cache.discoveriesByGuid or {}
    local existingIdx = Cache.discoveriesByGuid[guid]
    if existingIdx and Cache.discoveries[existingIdx] then
        local old = Cache.discoveries[existingIdx]
        if old.discovery and old.discovery.i and not old.isUndiscovered and not old.isVendor then
            AdjustDuplicateCount(old.discovery.i, -1)
        end
        Cache.discoveries[existingIdx] = row
        Cache.discoveriesByGuid[guid] = existingIdx
    else
        local idx = #Cache.discoveries + 1
        Cache.discoveries[idx] = row
        Cache.discoveriesByGuid[guid] = idx
        if not isVendor then
            Cache.lastDiscoveryCount = (Cache.lastDiscoveryCount or 0) + 1
        end
    end

    if not isVendor and discovery.i then
        AdjustDuplicateCount(discovery.i, 1)
    end

    InvalidateViewerFilterCache()
    return true
end

function Viewer:RemoveDiscoveryFromCache(guid)
    if not guid then return false end
    if not Cache.discoveriesBuilt or Cache.discoveriesBuilding then return false end

    Cache.discoveriesByGuid = Cache.discoveriesByGuid or {}
    local idx = Cache.discoveriesByGuid[guid]
    if not idx or not Cache.discoveries[idx] then
        return false
    end

    local row = Cache.discoveries[idx]
    local wasVendor = row.isVendor
    RemoveCacheRowAtIndex(idx)
    if not wasVendor then
        Cache.lastDiscoveryCount = math.max(0, (Cache.lastDiscoveryCount or 1) - 1)
    end

    InvalidateViewerFilterCache()
    return true
end

function Viewer:ConfirmDelete(discoveryData)
    local itemName = discoveryData.itemName
    local zone = GetLocalizedZoneName(discoveryData.discovery)

    StaticPopup_Show("LOOTCOLLECTOR_VIEWER_DELETE",
        string.format("Delete discovery for '%s' in '%s'?", itemName, zone),
        nil,
        { guid = discoveryData.guid, viewer = self }
    )
end

function Viewer:DeleteDiscovery(guid)
    local Core = L:GetModule("Core", true)
    if not Core then return end

    self.ignoreNextRemoveMessage = guid 

    local isVendor = false
    local dbV = L:GetVendorsDB()
    if dbV and dbV[guid] then
        isVendor = true
    end

    if isVendor then
        if Core.RemoveBlackmarketVendorByGuid then
            Core:RemoveBlackmarketVendorByGuid(guid)
        end
    else
        if Core.ReportDiscoveryAsGone then
            Core:ReportDiscoveryAsGone(guid)
        end
    end

    
    
    Cache.discoveriesBuilt = false
    self:RefreshData()
    self:UpdateClearAllButton()
end

function Viewer:FindDiscoveriesByPlayer(playerName)
    if not playerName or playerName == "" then return {} end
    local discoveriesByPlayer = {}
    local discoveries = L:GetDiscoveriesDB()
    for guid, discovery in pairs(discoveries or {}) do
        if discovery and type(discovery) == "table" and discovery.fp == playerName then
            _tinsert(discoveriesByPlayer, { guid = guid, discovery = discovery })
        end
    end
    return discoveriesByPlayer
end

function Viewer:DeleteAllFromPlayer(playerName)
    if not playerName or playerName == "" then return 0 end

    local discoveriesToDelete = self:FindDiscoveriesByPlayer(playerName)
    local deletedCount = 0

    local Core = L:GetModule("Core", true)
    if Core and Core.RemoveDiscovery then
        for _, data in ipairs(discoveriesToDelete) do
            if Core:RemoveDiscovery(data.guid) then
                deletedCount = deletedCount + 1
            end
        end
    end

    if deletedCount > 0 then
        print(string.format("|cff00ff00LootCollector:|r Deleted %d discoveries from player '%s'.", deletedCount, playerName))
        if self.window and self.window:IsShown() then
            self:UpdateAllDiscoveriesCache(function()
                self:GetFilteredDiscoveries()
                self:UpdateRows()
            end)
        end
    end

    return deletedCount
end

function Viewer:ConfirmDeleteAllFromPlayer(playerName)
    if not playerName or playerName == "" then return end

    local discoveriesByPlayer = self:FindDiscoveriesByPlayer(playerName)
    local count = #discoveriesByPlayer

    if count == 0 then
        print(string.format("|cffff7f00LootCollector:|r No discoveries found for player '%s'.", playerName))
        return
    end

    StaticPopup_Show("LOOTCOLLECTOR_VIEWER_DELETE_ALL_FROM_PLAYER",
        string.format("Delete all %d discoveries from player '%s'?", count, playerName),
        nil,
        { playerName = playerName, viewer = self, count = count }
    )
end

function Viewer:BlockAndPurgePlayer(playerName)
    if not playerName or playerName == "" then return end

    local fpName = L:normalizeSenderName(playerName)
    if not fpName then return end

    StaticPopup_Show("LOOTCOLLECTOR_VIEWER_BLOCK_AND_PURGE_PLAYER",
        string.format("Block player '%s' and permanently purge all their discoveries? You will no longer receive or display data from them.", playerName),
        nil,
        { fpName = fpName, viewer = self }
    )
end

function Viewer:ShowOnMap(discoveryData)
    local discovery = discoveryData.discovery or discoveryData
    if not discovery.g and discoveryData.guid then discovery.g = discoveryData.guid end
    if not discovery then
        print("LootCollector Viewer: No map data available for this discovery.")
        return
    end

    local Map = L:GetModule("Map", true)
    if not (Map and Map.FocusOnDiscovery) then
        print("LootCollector Viewer: Map module is not available.")
        return
    end

    local windowName = self.window and self.window:GetName()
    local wasInSpecialFrames = false
    if windowName then
        wasInSpecialFrames = removeFromSpecialFrames(windowName)
    end

    Map:FocusOnDiscovery(discovery)
    
    if WorldMapFrame and WorldMapFrame.Raise then
        WorldMapFrame:Raise()
    end
    
    if wasInSpecialFrames and windowName then
        self.restoreToSpecialFrames = true
        self.windowNameToRestore = windowName
        self.inMapOperation = true 
    end
end

function Viewer:ApplySettings()
    if L.db and L.db.profile and L.db.profile.viewer then
        ROW_HEIGHT = L.db.profile.viewer.rowHeight or 28
        ROW_FONT_SIZE = L.db.profile.viewer.rowFontSize or 14
        ROW_FONT_PATH = L.db.profile.viewer.rowFont or "Fonts\\ARIALN.TTF"
        UI_FONT_SIZE = L.db.profile.viewer.uiFontSize or 13
        UI_FONT_PATH = L.db.profile.viewer.uiFont or "Fonts\\ARIALN.TTF"
        -- Inline vendor expansion is now the ONLY vendor view. The old
        -- bottom split-pane (vendorInventoryFrame + splitterBar) caused
        -- visual glitches when dragging the window on the Vendors tab and
        -- has been retired; all its code paths are gated behind this flag.
        self.inlineVendorView = true
        L.db.profile.viewer.inlineVendorView = true
        self.splitRatio = L.db.profile.viewer.splitRatio or 0.64
    end
    
    local listFont = _G[ROW_FONT_NAME]
    if listFont then
        listFont:SetFont(ROW_FONT_PATH, ROW_FONT_SIZE, "OUTLINE")
        listFont:SetShadowColor(0, 0, 0, 0.8)
        listFont:SetShadowOffset(1, -1)
    end
    
    local uiFont = _G[UI_FONT_NAME]
    if uiFont then
        uiFont:SetFont(UI_FONT_PATH, UI_FONT_SIZE, "OUTLINE")
        uiFont:SetShadowColor(0, 0, 0, 0.8)
        uiFont:SetShadowOffset(1, -1)
    end
    
    
    if self.window then
        self:UpdateSortHeaders()
        for i, row in ipairs(self.rows) do
            row:SetHeight(ROW_HEIGHT)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            for _, child in ipairs({row:GetChildren()}) do
                if child.SetHeight then child:SetHeight(ROW_HEIGHT) end
            end
        end
        self:UpdateLayout()
        self:UpdateRows()
    end
end

function Viewer:OnGetItemInfoReceived(itemID)
    if not itemID then return end

    Cache.uniqueValuesContext = {}

    local baseID = L:GetBaseItemID(itemID)
    local isWF = L.WorldforgedSet and L.WorldforgedSet[baseID]

    if Cache.discoveriesBuilt and Cache.discoveries then
        local updatedAny = false
        for _, row in ipairs(Cache.discoveries) do
            local currentID = row.displayItemID or (row.discovery and row.discovery.i)
            if not row.isVendor and currentID and tonumber(currentID) == tonumber(itemID) then
                local itemLink = row.discovery.il or currentID
                local name, link, quality, itemLevelVal, minLevel, itemTypeVal, itemSubTypeVal, _, equipLocVal = GetItemInfoSafe(itemLink, itemID)
                if name then
                    local Scanner = L:GetModule("Scanner", true)
                    local itemData = Scanner and Scanner:GetItemData(itemID, itemLink) or {}
                    local isMystic = IsMysticScroll(name)
                    local isWorldforged = itemData.isWF or false
                    
                    local characterClass = ""
                    local classToken = itemData.classToken
                    if classToken then
                        characterClass = _G.LOCALIZED_CLASS_NAMES_MALE[classToken] or _G.LOCALIZED_CLASS_NAMES_FEMALE[classToken] or classToken
                    end

                    local finalMinLevel = itemData.reqLevel or minLevel or 0
                    local it, ist = row.discovery.it, row.discovery.ist
                    if not it or not ist or it == 0 or ist == 0 then
                        it, ist = GetItemTypeIDs(itemTypeVal, itemSubTypeVal)
                    end

                    local isNew = row.isUndiscovered or false
                    if not isNew and itemID and L.db and L.db.global and L.db.global.newWorldforgedItems then
                        isNew = L.db.global.newWorldforgedItems[itemID] or false
                    end
                    row.isNew         = isNew
                    row.itemName      = name
                    row.isMystic      = isMystic
                    row.isWorldforged = isNew and true or isWorldforged
                    row.itemType      = itemTypeVal
                    row.itemSubType   = itemSubTypeVal
                    row.it            = it
                    row.ist           = ist
                    row.equipLoc      = equipLocVal
                    row.characterClass= characterClass
                    row.itemLevel     = itemLevelVal
                    row.minLevel      = finalMinLevel
                    row.sortName      = name
                    row.sortClass     = characterClass or ""
                    row.sortType      = itemSubTypeVal or ""
                    row.sortSlot      = equipLocVal and _G[equipLocVal] or ""
                    updatedAny = true
                end
            end
        end

        if updatedAny then
            local stillHasUncached = false
            for _, row in ipairs(Cache.discoveries) do
                if not row.isVendor then
                    if not row.itemName or row.itemName:find("Unknown Item", 1, true) or (not row.itemType and not row.isMystic) then
                        stillHasUncached = true
                        break
                    end
                end
            end
            self.hasUncachedData = stillHasUncached
            self:UpdateReloadHint()

            -- Healed rows may now be filterable differently (CoA relics,
            -- name searches); invalidate the cached filtered list too.
            self:ScheduleFilterInvalidation()
        elseif isWF then
            -- Check if this is a Worldforged item/upgrade that was skipped because it was uncached
            if self.window and self.window:IsShown() then
                if not self._refreshTimer then
                    self._refreshTimer = C_Timer.After(0.3, function()
                        self._refreshTimer = nil
                        if self.window and self.window:IsShown() then
                            self:RefreshData()
                        end
                    end)
                end
            end
        end
    else
        -- Rebuild needed once current cache finishes building
        if isWF then
            self._rebuildNeeded = true
        end
    end
end

function Viewer:OnInitialize()
    local pTime = L.ProfileStart and L:ProfileStart() 

    self:CreateWindow() 
    self:ApplySettings()
    self:RestoreLiveFilters()

    L:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID)
        Viewer:OnGetItemInfoReceived(itemID)
    end)

    L:RegisterMessage("LootCollector_DiscoveriesUpdated", function(event, action, guid, discoveryData)
        if not Viewer.window or not Viewer.window:IsShown() then
            Cache.discoveriesBuilt = false
            return
        end

        -- Rebuild already refreshes the grid; do not bump Refresh (New) for
        -- purge/remove messages emitted mid-build, or for delayed Comm "bulk"
        -- timers that fire right after a user-initiated Refresh.
        if Cache.discoveriesBuilding or Viewer._suppressPendingBumps then
            VDebug("DiscoveriesUpdated ignored (action=" .. tostring(action) ..
                ", building=" .. tostring(Cache.discoveriesBuilding) ..
                ", suppress=" .. tostring(Viewer._suppressPendingBumps) .. ")")
            return
        end
        
        local updated = false
        if action == "add" and guid and discoveryData then
            if Cache.discoveriesBuilt and not Cache.discoveriesBuilding then
                updated = self:AddDiscoveryToCache(guid, discoveryData)
            end
        elseif action == "update" and guid and discoveryData then
            if Cache.discoveriesBuilt and not Cache.discoveriesBuilding then
                updated = self:AddDiscoveryToCache(guid, discoveryData) 
            end
        elseif action == "remove" and guid then
            if self.ignoreNextRemoveMessage == guid then
                self.ignoreNextRemoveMessage = nil
            else
                if Cache.discoveriesBuilt and not Cache.discoveriesBuilding then
                    updated = self:RemoveDiscoveryFromCache(guid)
                end
            end
        elseif action == "clear" then
            Cache.discoveriesBuilt = false
            Cache.discoveries = {}
            wipe(Cache.discoveriesByGuid)
            Cache.filteredResults = {}
            Cache.lastFilterState = nil
            Cache.uniqueValuesValid = false
            Cache.uniqueValuesContext = {}
            Cache.duplicateItems = {}
            Cache.lastDiscoveryCount = 0
            
            self.pendingUpdatesCount = 0
            self:UpdateRefreshButton()
            self:RefreshData()
            return
        else
            if Cache.discoveriesBuilt and not Cache.discoveriesBuilding then
                InvalidateViewerFilterCache()
                Cache.uniqueValuesContext = {}
                updated = true
            end
        end
        
        if updated then
            self.pendingUpdatesCount = (self.pendingUpdatesCount or 0) + 1
            PendingTraceRecord(action, guid, discoveryData)
            VDebug("Refresh (New): pending=" .. tostring(self.pendingUpdatesCount) ..
                " action=" .. tostring(action))
            self:UpdateRefreshButton()
        end
    end)

    if WorldMapFrame then
        local poller = CreateFrame("Frame")
        poller.lastVisible = WorldMapFrame:IsShown() and true or false
        poller:SetScript("OnUpdate", function(self)
            local isVisible = WorldMapFrame:IsShown() and true or false
            if self.lastVisible and not isVisible then
                if Viewer.restoreToSpecialFrames and Viewer.windowNameToRestore then
                    createTimer(0.1, function()
                        if Viewer.window and Viewer.window:IsShown() then
                            addToSpecialFrames(Viewer.windowNameToRestore)
                        end
                        Viewer.restoreToSpecialFrames = false
                        Viewer.windowNameToRestore = nil
                        Viewer.inMapOperation = false 
                    end)
                end
            end
            self.lastVisible = isVisible
        end)
    end

    -- Opening the world map (M) calls CloseSpecialWindows(), which would hide
    -- Discoveries (it is a UISpecialFrame). ESC also uses CloseSpecialWindows.
    -- Protect Discoveries only when the map ends up open and the setting says
    -- keep it open; otherwise let ESC close Discoveries like other windows.
    if type(CloseSpecialWindows) == "function" and not Viewer._closeSpecialWindowsHooked then
        Viewer._closeSpecialWindowsHooked = true
        local originalCloseSpecialWindows = CloseSpecialWindows
        CloseSpecialWindows = function(...)
            local window = Viewer.window or _G.LootCollectorViewerWindow
            local windowName = window and window:GetName()
            local protect = window and window:IsShown() and windowName
                and L.db and L.db.profile and L.db.profile.viewer
                and not L.db.profile.viewer.closeOnWorldMap

            local wasSpecial = false
            if protect then
                wasSpecial = removeFromSpecialFrames(windowName)
            end

            local result = originalCloseSpecialWindows(...)

            if protect and wasSpecial then
                createTimer(0, function()
                    if not window or not windowName then return end
                    local mapOpen = WorldMapFrame and WorldMapFrame:IsShown()
                    if mapOpen then
                        -- Map open path (M): keep Discoveries up and re-register ESC.
                        if window:IsShown() then
                            addToSpecialFrames(windowName)
                        end
                    else
                        -- ESC / clear-UI with map closed: close Discoveries now.
                        if window:IsShown() then
                            Viewer.allowManualClose = true
                            window:Hide()
                        end
                    end
                end)
            end
            return result
        end
    end

    self:UpdateClearAllButton()
    self:UpdateFilterButtonStates()
    
    
    -- Clean the PERSISTENT lookup queue once per login: drop upgrade
    -- variants that don't match the currently selected phase (the queue
    -- lives in db.global and can carry thousands of stale upgrade lookups
    -- from a phase selected in a previous session, starving base items).
    C_Timer.After(8, function()
        local phase = L.db and L.db.profile and L.db.profile.viewer and L.db.profile.viewer.worldforgedPhase or 0
        if Viewer.PruneStaleUpgradeCacheQueue then
            Viewer:PruneStaleUpgradeCacheQueue(phase)
        end
    end)

    -- Discovery-cache prewarm is deferred to Viewer:Show (avoids login hitch
    -- from building ~1.8k WF rows before the window is needed).
    
    if pTime then L:ProfileStop("Viewer:OnInitialize", pTime) end 
end

function Viewer:Show()
    local pTime = L.ProfileStart and L:ProfileStart() 

    if not self.window then self:CreateWindow() end
    
    
    if not self.window then 
        if pTime then L:ProfileStop("Viewer:Show", pTime) end
        return 
    end
    
    local t0 = time()
    VDebug("Show: start, currentFilter=" .. tostring(self.currentFilter) .. ", cacheBuilt=" .. tostring(Cache.discoveriesBuilt) .. ", building=" .. tostring(Cache.discoveriesBuilding))

    -- First open: start Worldforged GetItemInfo warm (gated off login).
    if L.StartWorldforgedListWarm then
        L.StartWorldforgedListWarm()
    end
    -- Phase upgrades (if selected) use the cancellable Viewer warm path.
    if self.PrewarmActivePhaseUpgrades then
        self:PrewarmActivePhaseUpgrades()
    end

    local Core = L:GetModule("Core", true)
    local isCoA = Core and Core.IsConfirmedCoARealm and Core:IsConfirmedCoARealm()
    
    self.currentFilter = self.currentFilter or "eq"
    if isCoA and self.currentFilter == "ms" then self.currentFilter = "eq" end
    
    self.window:SetFrameStrata(FRAME_STRATA)
    self.window:SetFrameLevel(FRAME_LEVEL)

    self.pendingUpdatesCount = 0
    self:UpdateRefreshButton()

    self.window:Show()

    -- Cheap re-anchor after showing: rows are created while the window is
    -- hidden and can carry stale rects into the first drag.
    if self.rows and self.scrollFrame then
        for i, r in ipairs(self.rows) do
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        end
    end
    self.currentPage = self.currentPage or 1
    self.currentFilter = self.currentFilter or "eq"
    self:UpdateFilterButtons()
    self:UpdateSortHeaders()
    self:UpdateFilterButtonStates()
    self:RefreshData()

    self.pendingMapAreaID = nil
    VDebug("Show: end, elapsed=" .. tostring(time() - t0) .. "s")
    
    if pTime then L:ProfileStop("Viewer:Show", pTime) end 
end

function Viewer:Hide()
    if self.PersistLiveFilters then self:PersistLiveFilters() end
    if self.window then self.window:Hide() end
    self.pendingMapAreaID = nil
    Cache.discoveriesBuilding = false
    scanQueue = {}
    scanCursor = 0
end

function Viewer:Toggle()
    if self.window and self.window:IsShown() then self:Hide() else self:Show() end
end

StaticPopupDialogs["LOOTCOLLECTOR_VIEWER_SAVE_PRESET"] = {
    text = "Save current Discoveries filters as preset:\n(Max " .. MAX_FILTER_PRESETS .. "; same name overwrites)",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 220,
    OnShow = function(self)
        local editBox = _G[self:GetName() .. "EditBox"]
        if editBox then
            editBox:SetText("")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = _G[self:GetName() .. "EditBox"]
        local name = editBox and editBox:GetText() or ""
        Viewer:SaveFilterPreset(name)
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = self:GetText() or ""
        Viewer:SaveFilterPreset(name)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_VIEWER_DELETE_PRESET"] = {
    text = "Delete filter preset '%s'?",
    button1 = "Yes, Delete",
    button2 = "No, Cancel",
    OnAccept = function(self, data)
        if data and data.name then
            Viewer:DeleteFilterPreset(data.name)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_DISCORD_BUG_REPORT"] = {
    text = "Join our Discord to give feedback or report issues in #lootcollector:\n\nPress Ctrl+C to copy the link below.",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local editBox = _G[self:GetName() .. "EditBox"]
        if editBox then
            editBox:SetText("https://discord.gg/GmeSCJGdzs")
            editBox:SetFocus()
            editBox:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_VIEWER_DELETE"] = {
    text = "%s",
    button1 = "Yes, Delete",
    button2 = "No, Cancel",
    OnAccept = function(self, data)
        if data and data.viewer and data.guid then
            data.viewer:DeleteDiscovery(data.guid)
        end
    end,
    OnCancel = function(self, data)
        if data and data.viewer then
            data.viewer:UpdateRows() 
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_VIEWER_DELETE_ALL_FROM_PLAYER"] = {
    text = "%s",
    button1 = "Yes, Delete All",
    button2 = "No, Cancel",
    OnAccept = function(self, data)
        if data and data.viewer and data.playerName then
            data.viewer:DeleteAllFromPlayer(data.playerName)
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = true,
}

StaticPopupDialogs["LOOTCOLLECTOR_VIEWER_BLOCK_AND_PURGE_PLAYER"] = {
    text = "%s",
    button1 = "Yes, Block and Purge",
    button2 = "No, Cancel",
    OnAccept = function(self, data)
        if data and data.viewer and data.fpName then
            local targetName = data.fpName
            L.db.profile.sharing = L.db.profile.sharing or {}
            L.db.profile.sharing.blockList = L.db.profile.sharing.blockList or {}
            L.db.profile.sharing.blockList[targetName] = true
            
            local Core = L:GetModule("Core", true)
            if Core and Core.PurgeDiscoveriesFromBlockedPlayers then
                Core:PurgeDiscoveriesFromBlockedPlayers()
            end
            
            print(string.format("|cff00ff00LootCollector:|r Player '%s' has been blocked and all their discoveries purged.", targetName))
            
            data.viewer:UpdateAllDiscoveriesCache(function()
                data.viewer:GetFilteredDiscoveries()
                data.viewer:UpdateRows()
            end)
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = true,
}

SLASH_LootCollectorVIEWER1 = "/lcviewer"
SLASH_LootCollectorVIEWER2 = "/lcv"
SlashCmdList["LootCollectorVIEWER"] = function(msg)
    local raw = strtrim(msg or "")
    local cmd = string.lower(raw)
    if cmd == "" then
        Viewer:Toggle()
    elseif cmd == "clear" then
        Viewer:ClearCaches()
        print("LootCollector Viewer: All caches cleared")
    elseif cmd == "rebuild" then
        Viewer:ClearCaches()
        Viewer:UpdateAllDiscoveriesCache(function()
            print("LootCollector Viewer: Cache rebuilt")
            if Viewer.window and Viewer.window:IsShown() then
                Viewer:RefreshData()
            end
        end)
    elseif cmd == "pending" or cmd == "pending dump" then
        Viewer:DumpPendingTrace(false)
    elseif cmd == "pending on" then
        Viewer._pendingTraceEnabled = true
        Viewer._pendingTrace = Viewer._pendingTrace or {}
        print("|cff88aaff[LC-Pending]|r recording ON (ring of " ..
            tostring(Viewer._pendingTraceMax or 32) .. "). Use /lcviewer pending to dump.")
    elseif cmd == "pending off" then
        Viewer._pendingTraceEnabled = false
        if Viewer._pendingTrace then wipe(Viewer._pendingTrace) end
        print("|cff88aaff[LC-Pending]|r recording OFF (buffer cleared).")
    else
        print("LootCollector Viewer commands:")
        print("/lcviewer - Toggles viewer window")
        print("/lcviewer clear - Clears all caches")
        print("/lcviewer rebuild - Rebuilds all caches")
        print("/lcviewer pending on - Record pending Refresh events (dev)")
        print("/lcviewer pending off - Stop recording and clear buffer")
        print("/lcviewer pending - Dump recorded pending events")
    end
end

return Viewer

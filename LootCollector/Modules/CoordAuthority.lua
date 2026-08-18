-- Maintainer-verified Worldforged coordinates.
-- This table is the only supported way to move high-mc pins. Do not
-- auto-harvest community mc into authority.
--
-- Loop: stand on the spawn → /lcsetcoords → paste the printed Lua row →
-- bump CoordAuthorityRevision → release. Prioritize /lcdiag rows that
-- are HIGH_MC and whose GUID xy differs from stored xy.
--
-- Bump CoordAuthorityRevision whenever you add or change a row so login re-applies.
-- Players' SavedVariables are snapped on login; public DISC cannot override these xy.

local L = LootCollector

L.CoordAuthorityRevision = 3
L.CoordAuthority = {
    [410154] = { [24] = { c = 2, x = 0.6156, y = 0.6831 } }, -- Plaguebloom Spear, Eastern Plaguelands
    [415038] = { [17] = { c = 2, x = 0.4011, y = 0.3038 } }, -- Plains Bolter, Arathi Highlands
    [515014] = { [21] = { c = 2, x = 0.4956, y = 0.3613 } }, -- Agamand Farmer Trousers, Tirisfal Glades
    [521029] = { [21] = { c = 2, x = 0.4610, y = 0.2958 } }, -- Agamand Sharpshooter, Tirisfal Glades
    [521034] = { [21] = { c = 2, x = 0.5669, y = 0.4996 } }, -- Ghostmoor Cloak, Tirisfal Glades
    [521033] = { [21] = { c = 2, x = 0.5880, y = 0.3084 } }, -- Maggot Eye Musket, Tirisfal Glades
    [521030] = { [21] = { c = 2, x = 0.6574, y = 0.5968 } }, -- Nightfallen Jerkin, Tirisfal Glades
    [515007] = { [21] = { c = 2, x = 0.5318, y = 0.5779 } }, -- Old Wagon Wheel, Tirisfal Glades
    [450869] = { [21] = { c = 2, x = 0.5982, y = 0.4809 } }, -- Ulag's Cleaver, Tirisfal Glades
    [515043] = { [21] = { c = 2, x = 0.3500, y = 0.4343 } }, -- Waterlogged Sparkler, Tirisfal Glades
}

-- Item must not exist in this zone. Delete the pin; do not merge onto
-- another zone of the same item (that would steal a different spawn's xy).
-- Bump ForbiddenZoneRevision once at RELEASE_Notes, not per row.
-- Apply runs every login (DISC can reintroduce the pin).
L.ForbiddenZoneRevision = 1
L.UntrackedItemIDs = {
    [500814] = true, -- Goldshire Traveler's Boots: not in game
    [500816] = true, -- Supply Runner's Pants: not in game
    [500817] = true, -- Scholar's Ring of Enlightenment: not in game
}
L.ForbiddenItemZones = {
    [217842] = { -- Bonechopper: Stranglethorn Vale only
        [29] = true,  -- Searing Gorge
    },
    [410224] = { -- Charbite Mace: Burning Steppes only
        [1205] = true, -- Blackrock Mountain
    },
    [354149] = { -- Kixxle's Experimental Potion: Wetlands is real
        [36] = true,  -- Loch Modan
        [38] = true,  -- Stranglethorn Vale
    },
    [354292] = { -- Recipe: Freshly Brewed Firewater: Felwood only
        [25] = true,  -- Hillsbrad Foothills
        [705] = true, -- Blackrock Depths
    },
    [354467] = { -- Recipe: Miru Berry Wine: Deadwind Pass only
        [23] = true,  -- Western Plaguelands
        [24] = true,  -- Eastern Plaguelands
    },
    [451107] = { -- Travel Sack upgrade: not in Mulgore
        [10] = true,  -- Mulgore
    },
    [500811] = { -- Morin's Jug: Loch Modan only
        [25] = true,  -- Hillsbrad Foothills
        [763] = true, -- Scarlet Monastery
    },
    [500813] = { -- Melika's Ring: none of the listed stamps are real
        [31] = true,  -- Elwynn Forest (Lexicon Ring spawn)
        [36] = true,  -- Loch Modan
        [40] = true,  -- Westfall
        [692] = true, -- Gnomeregan
        [754] = true, -- Blackrock Caverns
        [763] = true, -- Scarlet Monastery
    },
    [500819] = { -- Tome of Second Chances: not in Elwynn; Redridge Mountains stays
        [31] = true,  -- Elwynn Forest
    },
    [824378] = { -- Ancient Femur: Sinister Lair only (cave inside Valley of Trials)
        [5] = true,    -- Durotar
        [1244] = true, -- Valley of Trials
    },
}

function LootCollector:GetCoordAuthorityZones(itemID)
    itemID = tonumber(itemID)
    if not itemID or type(self.CoordAuthority) ~= "table" then
        return nil
    end
    local byItem = self.CoordAuthority[itemID]
    if not byItem and self.GetBaseItemID then
        local base = self:GetBaseItemID(itemID)
        if base and base ~= itemID then
            byItem = self.CoordAuthority[base]
        end
    end
    if type(byItem) ~= "table" or not next(byItem) then
        return nil
    end
    return byItem
end

function LootCollector:GetCoordAuthorityEntry(itemID, zoneID)
    zoneID = tonumber(zoneID)
    if not zoneID then return nil end
    local byItem = self:GetCoordAuthorityZones(itemID)
    if not byItem then return nil end
    return byItem[zoneID] or byItem[tostring(zoneID)]
end

-- If the item has CoordAuthority rows, only those zones are valid.
-- No rows means unrestricted (StarterDB / live discovery still apply).
function LootCollector:IsCoordAuthorityZoneAllowed(itemID, zoneID)
    local zones = self:GetCoordAuthorityZones(itemID)
    if not zones then return true end
    zoneID = tonumber(zoneID)
    if not zoneID then return false end
    return zones[zoneID] ~= nil or zones[tostring(zoneID)] ~= nil
end

function LootCollector:IsItemZoneForbidden(itemID, zoneID)
    itemID = tonumber(itemID)
    zoneID = tonumber(zoneID)
    if not itemID or not zoneID or type(self.ForbiddenItemZones) ~= "table" then
        return false
    end
    local byItem = self.ForbiddenItemZones[itemID]
    if not byItem and self.GetBaseItemID then
        local base = self:GetBaseItemID(itemID)
        if base and base ~= itemID then
            byItem = self.ForbiddenItemZones[base]
        end
    end
    if type(byItem) ~= "table" then
        return false
    end
    return byItem[zoneID] == true or byItem[tostring(zoneID)] == true
end

function LootCollector:IsUntrackedWorldforged(itemID)
    itemID = tonumber(itemID)
    if not itemID or type(self.UntrackedItemIDs) ~= "table" then
        return false
    end
    if self.UntrackedItemIDs[itemID] then
        return true
    end
    if self.GetBaseItemID then
        local base = self:GetBaseItemID(itemID)
        if base and self.UntrackedItemIDs[base] then
            return true
        end
    end
    return false
end

function LootCollector:LockDiscoveryToCoordAuthority(rec)
    if type(rec) ~= "table" then return false end
    local entry = self:GetCoordAuthorityEntry(rec.i, rec.z)
    if not entry then return false end
    rec.xy = rec.xy or {}
    rec.xy.x = self:Round4(entry.x)
    rec.xy.y = self:Round4(entry.y)
    if entry.c then
        rec.c = tonumber(entry.c) or rec.c
    end
    return true
end

-- Record in the player's current zone. When the world map is closed, do
-- not SetMapZoom back to leftover continent/zone (3.3.5 keeps the last
-- viewed AreaID after the map UI closes; restoring it is what stamped
-- capital upgrades onto EPL/Azshara). When the map is open, restore so
-- we do not steal the viewed zone.
function LootCollector:GetPlayerZoneMapPosition()
    local mapOpen = WorldMapFrame and WorldMapFrame:IsVisible()
    local sc, sz, sdl
    if mapOpen then
        sc = GetCurrentMapContinent and GetCurrentMapContinent() or 0
        sz = GetCurrentMapZone and GetCurrentMapZone() or 0
        sdl = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel() or 0
    end

    local Map = self:GetModule("Map", true)
    if Map and Map.UnregisterEvent then
        Map:UnregisterEvent("WORLD_MAP_UPDATE")
    end

    if SetMapToCurrentZone then SetMapToCurrentZone() end
    local px, py = GetPlayerMapPosition("player")
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local c = GetCurrentMapContinent and GetCurrentMapContinent() or 0

    local zoneName = GetRealZoneText and GetRealZoneText() or ""
    if zoneName ~= "" and mapID and mapID > 0 then
        local ZoneList = self:GetModule("ZoneList", true)
        local info = ZoneList and ZoneList.MapDataByID and ZoneList.MapDataByID[mapID]
        if info and info.name and string.lower(info.name) ~= string.lower(zoneName) then
            -- Leftover/viewed AreaID. Do not report it.
            c, mapID, px, py = 0, 0, 0, 0
        end
    end

    if mapOpen then
        if SetMapZoom and sc and sz then SetMapZoom(sc, sz) end
        if SetDungeonMapLevel and sdl then SetDungeonMapLevel(sdl) end
    end

    if Map and Map.BindWorldMapUpdate then
        Map:BindWorldMapUpdate()
    end

    return c, mapID, px or 0, py or 0
end

function LootCollector:FormatCoordAuthoritySnippet(itemID, zoneID, c, x, y, itemName)
    itemID = tonumber(itemID) or 0
    zoneID = tonumber(zoneID) or 0
    c = tonumber(c) or 0
    x = self:Round4(x or 0)
    y = self:Round4(y or 0)
    local comment = itemName and (" -- " .. tostring(itemName)) or ""
    return string.format(
        "    [%d] = { [%d] = { c = %d, x = %.4f, y = %.4f } },%s",
        itemID, zoneID, c, x, y, comment
    )
end

local function ResolveSetCoordsRecord(msg)
    local db = L.GetDiscoveriesDB and L:GetDiscoveriesDB()
    if not db then return nil, "Discovery database not ready." end

    local itemID = tonumber(msg)
    if not itemID and msg and msg ~= "" then
        itemID = tonumber(msg:match("item:(%d+)"))
    end

    if itemID then
        local queryBase = (L.GetBaseItemID and L:GetBaseItemID(itemID)) or itemID
        local _, mapID = L:GetPlayerZoneMapPosition()
        local matches, zoneMatches = {}, {}
        for guid, d in pairs(db) do
            if type(d) == "table" and d.i and not d.vendorType then
                local diBase = (L.GetBaseItemID and L:GetBaseItemID(d.i)) or d.i
                if d.i == itemID or diBase == queryBase then
                    table.insert(matches, d)
                    if tonumber(d.z) == tonumber(mapID) then
                        table.insert(zoneMatches, d)
                    end
                end
            end
        end
        local pool = (#zoneMatches > 0) and zoneMatches or matches
        if #pool == 0 then
            return nil, "No local discovery for item " .. tostring(itemID) .. "."
        end
        table.sort(pool, function(a, b)
            local amc, bmc = tonumber(a.mc) or 1, tonumber(b.mc) or 1
            if amc ~= bmc then return amc > bmc end
            return (tonumber(a.ls) or 0) > (tonumber(b.ls) or 0)
        end)
        return pool[1]
    end

    local Viewer = L:GetModule("Viewer", true)
    local row = Viewer and Viewer.selectedRow
    local data = row and (row.discoveryData or row)
    local guid = data and (data.guid or (data.discovery and data.discovery.g))
    if guid and db[guid] then
        return db[guid]
    end
    return nil, "Select a Discoveries row or pass /lcsetcoords <itemID>."
end

SLASH_LOOTCOLLECTORSETCOORDS1 = "/lcsetcoords"
SlashCmdList["LOOTCOLLECTORSETCOORDS"] = function(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$") or ""
    if msg == "help" then
        print("|cff00ff00LootCollector:|r /lcsetcoords [itemID] - snap a pin to your position and print a CoordAuthority snippet.")
        print("|cffaaaaaaMaintainer loop: stand on the spawn, run this, paste the Lua row, bump CoordAuthorityRevision, release.|r")
        print("|cffaaaaaaPrioritize /lcdiag HIGH_MC rows where GUID xy differs from stored xy. Do not harvest community mc.|r")
        return
    end

    local rec, err = ResolveSetCoordsRecord(msg)
    if not rec then
        print("|cffff7f00LootCollector:|r " .. tostring(err or "No discovery selected."))
        return
    end
    if rec.vendorType then
        print("|cffff7f00LootCollector:|r /lcsetcoords is for Worldforged pins, not vendors.")
        return
    end

    local c, mapID, px, py = L:GetPlayerZoneMapPosition()
    if rec.z and tonumber(rec.z) ~= tonumber(mapID) then
        print(string.format(
            "|cffff7f00LootCollector:|r Stand in the pin's zone to snap it (pin z=%s, you are z=%s).",
            tostring(rec.z), tostring(mapID)
        ))
        return
    end
    if (px == 0 and py == 0) or not mapID or mapID == 0 then
        print("|cffff7f00LootCollector:|r Could not read your map position. Close loading screens and try again.")
        return
    end

    rec.xy = rec.xy or {}
    rec.xy.x = L:Round4(px)
    rec.xy.y = L:Round4(py)
    rec.c = tonumber(c) or rec.c
    rec.ls = time()
    L.DataHasChanged = true

    local Map = L:GetModule("Map", true)
    if Map then
        Map.cacheIsDirty = true
        if Map.Update and WorldMapFrame and WorldMapFrame:IsShown() then Map:Update() end
        if Map.UpdateMinimap then Map:UpdateMinimap() end
    end
    local Viewer = L:GetModule("Viewer", true)
    if Viewer and Viewer.NotifyDatabaseChanged then
        Viewer:NotifyDatabaseChanged()
    end
    L:SendMessage("LootCollector_DiscoveriesUpdated", "update", rec.g, rec)

    local itemID = (L.GetBaseItemID and L:GetBaseItemID(rec.i)) or rec.i
    local itemName = rec.il and rec.il:match("%[(.+)%]") or select(1, GetItemInfo(rec.i))
    print("|cff00ff00LootCollector:|r Snapped pin to " .. string.format("%.2f, %.2f", rec.xy.x * 100, rec.xy.y * 100) .. ".")
    print("|cffaaaaaaPaste into CoordAuthority.lua and bump CoordAuthorityRevision:|r")
    print(L:FormatCoordAuthoritySnippet(itemID, rec.z, rec.c, rec.xy.x, rec.xy.y, itemName))
end

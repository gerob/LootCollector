# LootCollector - Claude Fable Developer Handshake & Changelog (0.8.9s)

## 0.8.9s — Fable's pass (2026-07-19)

**Root cause of the phase-selector bug** (undiscovered Worldforged items being removed): in the Viewer cache build, undiscovered rows were vetoed by `IsWorldforged(itemLink)` — a tooltip scan of lines 2–5 only, with permanent negative caching and no "Retrieving item information" guard — evaluated against the *upgraded* variant's link when a phase was active. While the upgrade was uncached the row was kept ("assume true"); once the addon's own cache-warming completed, the next rebuild removed it. Fixes:

1. **Viewer.lua** — undiscovered rows from the curated `WorldforgedList` are always `isWorldforged = true` (no tooltip veto); discovered rows judge WF status from the BASE link only. `IsWorldforged` scans all lines, guards RETRIEVING_TEXT, never caches negatives from partial tooltips.
2. **Viewer.lua** — `UpdateAllDiscoveriesCache` (async) filled a local `scanQueue` that `ProcessCacheBuildChunk` never read (it consumes `_cacheBuildQueue`), so async rebuilds completed instantly with an empty cache. Now delegates to the chunked builder with a forced rebuild. `RefreshData` clears `discoveriesBuilt` before rebuilding (the builder's guard used to skip data-changed rebuilds).
3. **Viewer.lua** — undiscovered/phase rows borrow base-item metadata while upgrade data is in flight; base IDs are queued for caching alongside upgrades; `discoveredItemIDs` normalizes via `GetBaseItemID`.
4. **WorldforgedUpgrades.lua** — recovered 6 rows that are syntactically broken in AtlasLoot's `ItemIDsDatabaseFixes.lua` (`= nil,nil,nil,{...}` assigns only the first nil): 1262811, 2088888, 3595662, 4050651–53. Report upstream to the AtlasLoot maintainer.
5. **Comm.lua** — memory leak: `pruneCaches` read `Comm.seen` (never assigned) instead of `Comm._seen`, so the dedupe table grew unboundedly all session. Also: early read-only duplicate peek for DISC/CONF before any allocation (placed AFTER the spam sentinel so its counting still works), guarded hot-path debug string builds, pruned stale sender-rate windows.
6. **Core.lua** — `AddDiscovery`'s Teldrassil/Ashenvale zone-correction scan iterated the whole DB per accepted message; now gated on incoming zone ∈ {41, 242, 122} (the only zones whose correction can trigger; see `getPreferredZone` — assignment requires `incorrectZ == z`).
7. **LootCollector.lua** — profiler defaults OFF (`/lcprofiler on|off|report|reset` to use it); `IsWorldforgedUpgradeable` memoized (was a GetItemInfo per call inside pin refresh loops).
8. **Viewer.lua filters** — Clear buttons now reset Favorites; unfavoriting under the Favorites filter invalidates the cached list; flat column filters (zone/source/quality/looted/vendorType) and the WF phase are now part of `GetFilterStateHash`; Vendors-tab Type/Price/Continent sorts no longer fall back to GUID ordering; page clamped when the result set shrinks; undiscovered rows participate in dropdown option building; Deep Search toggle no longer forces a full cache rebuild.

**Key invariant:** AtlasLoot difficulty indices for WorldforgedClassic are 3=Base, 4=Dungeon, 5=ZG, 6=T1, 7=T2, 8=AQ, 9=T3; LC's `viewer.worldforgedPhase` (0–6) maps via `upgrades[phase + 3]`. `WorldforgedUpgrades.lua` is an export of AtlasLoot's `ItemIDsDatabaseCorrectedIDs`; `WorldforgedList.lua` matches AtlasLoot's `WorldforgedClassic` list 1:1 (1838 items).

---

# Previous handshake (0.8.9r, Gemini/Antigravity)

Welcome, **Fable**! This document provides a comprehensive summary of the LootCollector addon's architecture, its core purpose, and a complete chronological changelog of the features and bug fixes implemented during our recent development cycles for version `0.8.9r`.

---

## 1. What is LootCollector?
**LootCollector** is a community-driven database-sharing and navigation addon built for **Project Ascension** (World of Warcraft 3.3.5a client modification). 
Its core capabilities are:
* **Crowdsourced Database:** Shares coordinates of looted Worldforged gear chests, rare items, and custom chest spawns in real-time between players via hidden chat channel comms.
* **Navigation Overlay:** Plots discoveries directly on the World Map and Minimap, and hooks into **TomTom** to direct players to the nearest upgrade.
* **Discovery Viewer (`/lcv`):** A custom paginated grid GUI where players can search, filter, class-restrict, slot-restrict, and preview all world discoveries.

---

## 2. Technical Architecture & Data Flow
* **SavedVariables (Realm Buckets):** Player discoveries and comm databases are separated cleanly by realm (Bronzebeard, seasonal, main) to prevent mixed seasonal/ruleset data.
* **Asynchronous Client-Server Caching:** WoW's client-server item query is async. If an item isn't cached locally in `cache/` or client RAM, `GetItemInfo(itemID)` returns `nil` and queries the server. LootCollector has a background query queue to pre-warm item cache.
* **Dynamic Rebuilding:** The viewer cache is built asynchronously in chunks across frames (to prevent game freezes).
* **Worldforged Upgrades Phase Selector:** In version `0.8.9r`, we added the ability to preview upgrades for all baseline Worldforged items across different phases (Base, Pre-Raid P0, ZG P1, MC P2, BWL P3, AQ P4, Naxx P5).

---

## 3. Chronological Changelog for Version 0.8.9r

### A. Missing Items Count Indicator
* **Feature:** Added a missing items counter in parentheses directly to the **Undiscovered** filter button in the Discovery Viewer (e.g. `Undiscovered: Top (59)`). This displays exactly how many unique baseline Worldforged items the player has yet to discover.

### B. Integrated Phase Selection UI
* **Feature:** Replaced the previous standalone dropdown with an integrated UI directly on the **Worldforged** tab button.
  * **Interactive Label:** The button displays the active phase (e.g. `Worldforged - |cff00ff00P1|r ▼`).
  * **Mouse Bindings:** Left-clicking the active tab opens the phase dropdown selection menu. Right-clicking the tab toggles/opens the phase menu at any time.

### C. Complete Upgrade Phase Database (`WorldforgedUpgrades.lua`)
* **Database Expansion:** Re-generated and expanded the database mapping baseline items to their upgraded counterparts in every phase.
  * Spans all **1,973 upgrade mappings** available in the game database.
  * Handles sparse mappings gracefully (some items skip phases or have no phase-specific upgrades), automatically falling back to their base item IDs.
  * Excluded **Bags/Containers** (class ID 1, `INVTYPE_BAG`) from upgrades, as bag-swaps have identical tooltips and cause clutter.

### D. Client-Server Caching & "Unknown Item" Self-Healing
To combat the asynchronous nature of the WoW API where items often render as `Unknown Item (ID)` while waiting for server replies:
1. **Render-Time Resolver:** Added a JIT (just-in-time) metadata resolver in the row rendering loop (`UpdateRows`). If a row is rendered with `"Unknown Item"` but the client has since cached the data, the row automatically heals, populates its name/level/stats/slot, and saves it to the cache database.
2. **Debounced Rebuild Listener:** If a Worldforged item's data arrives from the server while the cache is building, the addon flags it and schedules a debounced rebuild `0.3` seconds after the current compilation finishes.
3. **Queue Syncing:** Updated the cache building sequence to queue upgraded item IDs (instead of base IDs) in the background caching queue so the client properly queries the upgrades.

### E. Dynamic Map Pin Quality Colors
* **Feature:** Updated map pins, minimap pins, hover details, and the proximity list to dynamically fetch the quality color and item tooltips of the upgraded phase item instead of the base item. Selecting higher phases dynamically upgrades pin colors (e.g. blue/rare to purple/epic).

### F. Smart Upgrade Indicator Arrows `▲`
* **Feature:** Added a small green triangle `▲` next to item names in the Viewer list.
  * **Conditional Visibility:** The arrow *only* displays when an upgrade phase is active (`selectedPhase > 0`) AND the item actually receives a different upgrade ID in that phase.
  * Base phase items and items that fall back to their base versions in the active phase display no arrows, making it easy to identify true upgrades.

### G. Performant Pre-warming
* **Optimization:** Modified login cache warming. The addon only pre-warms base items + upgraded items for the *currently active phase* on login (saving ~70% network traffic). When switching phases in the UI, it warms the new phase's upgrades in the background.

---

## 4. Key Files to Inspect
1. **[LootCollector.lua](file:///d:/Games/Ascension/Interface/AddOns/LootCollector/LootCollector.lua):** Main addon namespace, SavedVariables setup, and phase ID lookups (`GetWorldforgedPhaseItemID`, `IsWorldforgedUpgradeable`).
2. **[Modules/Viewer.lua](file:///d:/Games/Ascension/Interface/AddOns/LootCollector/Modules/Viewer.lua):** Discovery Viewer GUI, cache building queue, row resolver, and dropdown UI.
3. **[Modules/Map.lua](file:///d:/Games/Ascension/Interface/AddOns/LootCollector/Modules/Map.lua):** Map pin rendering, minimap dots, and hover tooltips.
4. **[Modules/WorldforgedUpgrades.lua](file:///d:/Games/Ascension/Interface/AddOns/LootCollector/Modules/WorldforgedUpgrades.lua):** Database containing all phase upgrades.

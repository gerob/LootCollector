# LootCollector 0.8.9s — Full Developer Changelog
## Claude Fable → Gemini (Antigravity) handoff — 2026-07-19

---

# EIGHTH PASS (build s8): the REAL vendor-detection blocker + pump lifecycle

- **P8.1 THE vendor fix (supersedes the P4/P6 gate bypasses as "the" root cause):** `Core:HandleLocalLoot` line ~2823: `local infoTarget = discovery.il or discovery.i; if not infoTarget then return end` -- Detect's vendor payloads carry NEITHER field (pseudo-item synthesized inside the vendor branch, which REASSIGNS the outer itemID local). Every live vendor detection died here; the user's /lcvendor (build s7) proved it: subname "Ring Vendor", rule match RING, merchant open, scan ran, no record. All existing vendor entries came from imports/StarterDB, never live detection -- this gate was almost certainly the dev's actual "disable". Fix: `isVendorPayload` (vendorType present or dt==BLACKMARKET) bypasses the infoTarget gate and the itemID==0 gate; GetItemInfo call made conditional; discovery.i only overwritten when non-zero. The P4/P6 zone-gate bypasses remain necessary for CITY vendors specifically.
- **P8.2 Pump lifecycle:** the cache pump self-cancels on empty queue; ONLY login (`EnsureCachePump` at +10s) restarted it. Phase switches (PrewarmActivePhaseUpgrades), viewer cache builds (chunk completion), and priority inserts now all call `Core:EnsureCachePump()` (internally guarded: autoCache, non-empty queue, already-active). This was "caching stuck at 0 / 1752 after switching phases".
- **P8.3 /lcvendor honesty:** previous logic said "may already be recorded" whenever the vendors DB was merely non-empty. Now scans for a vendorName match and reports Recorded / has-entry-but-check-tab / NOT-recorded distinctly.
- Field-verified in this pass (user screenshots, build s7): tooltip base-item fallback works; StarterDB v7.0 records visible with real zones/finders; /lcvendor diagnostic chain works end-to-end.

---

# SEVENTH PASS (build s7): caching freeze

- **P7.1 Root cause of "caching stuck at 0/1303"**: `ProcessCacheQueue`'s verify branch re-queued any ID for which `ShouldCacheItem` stayed true -- forever. Unreleased items (the ~250 not-yet-found WF items) and ALL their phase-upgrade IDs (e.g. 1389872) have no server data, so they never resolve; with P0 selected the row builder queues those upgrade IDs, and P5.1's priority bumping moved them to the FRONT. The pump then spent its whole time churning hopeless IDs (2s verify each, size never shrinking -> progress pinned at 0%). Fix: `Core._cacheAttempts` / `Core._cacheHopeless` (session tables) -- two failed verifies parks the ID; hopeless IDs skip instantly on later encounters; verify delay 2s -> 1.2s; `QueueItemForCachingPriority` refuses hopeless IDs. INVARIANT: never re-queue an ID unconditionally in the verify callback.
- **P7.2** nameFrame hover tooltip falls back to the BASE item (with a gray note) when `GetItemInfo(displayItemID)` is nil -- unreleased upgrades otherwise show "Retrieving item information" forever.
- **P7.3 Build stamp**: `L.BuildStamp = "s7"` (LootCollector.lua, NEXT TO L.Version -- deliberately NOT part of the comm `av` string, which other clients' version filters compare). Shown in the minimap tooltip title and the /lcvendor header; TOC Title suffix is [beta.0.8.9s-7]. Bump the stamp on every fix pass.
- **P7.4 Open question (awaiting field data)**: vendor map pins (P6.1) and Ring Vendor detection -- the user had not yet confirmed running build s6+ nor provided /lcvendor output; the build stamp exists to disambiguate exactly this.

---

# SIXTH PASS (same day): field-test round 3

- **P6.1 Vendor pins**: `LootCollector:DiscoveryPassesFilters` now short-circuits BLACKMARKET records to `return f.showVendors ~= false` (anchor `-- Vendors: gate ONLY by the "Vendors" show-toggle`). Root causes: (a) the `allowedEquipLoc` block ends in `elseif not equipLoc then return false`, and vendor pseudo-items never resolve an equip slot -> ANY active Slots filter dropped every vendor pin on world map + minimap; (b) `showVendors` was previously only read by Toast. ZoneIndex/RebuildZoneIndex already include vendors (verified) - the source pipeline was never the problem.
- **P6.2** `IsInsideAOETombstone` in HandleLocalLoot is now also gated by `not isSpecialVendorDiscovery` - the last zone gate that could silently block a city vendor recording.
- **P6.3 Drag ghost strategy v3**: hide-on-drag reverted (user disliked it). Rows stay visible; row anchor chains are refreshed (ClearAllPoints + SetPoint to scrollFrame) in Viewer:Show and in OnDragStart. Theory: rows are created while the window is hidden (CreateWindow ends with window:Hide()), leaving stale rects that survive until re-anchor. If the first-drag ghost STILL reproduces after this, the next step is a per-child re-anchor pass (favBtn/levelText/etc. chains) or reverting to hide-on-drag behind a setting.
- **P6.4 Cache pump**: TryCacheItem path delay 0.25-0.35s (was 0.5-0.7s). Combat/moving pauses unchanged. This plus the priority queue (P5.1) is the answer to "caching is super slow": it's an addon-side anti-flood throttle, not a server cap.
- NOTE for Ring Vendor debugging: detection is SUBNAME-based (not inventory). The user has not yet provided /lcvendor output; that command force-runs the scan and reports every gate. If the subname line shows "none", GetNPCSubname's digit-rejection or tooltip-line-2 assumptions are the next suspects.

---

# FIFTH PASS (same day): field-test round 2

- **P5.1 Priority caching**: `Core:QueueItemForCachingPriority(id)` (front-inserts, removes deep duplicate, restarts idle pump). Called from the UpdateRows JIT resolver when a visible row fails GetItemInfo (guarded once per row via `data._prioCached`). Root cause of "Unknown Item until hover": base items sat FIFO behind ~1,400 queued phase upgrades.
- **P5.2 Heal-time refiltering**: `Viewer:ScheduleFilterInvalidation()` (0.4s debounce) called from BOTH heal paths (JIT resolver + OnGetItemInfoReceived). Root cause of "Librams still visible on CoA": realm detection was fine (Vol'jin → COA); healed rows changed but the filter-state hash didn't, so the cached filtered list kept serving them.
- **P5.3 Login queue prune**: `PruneStaleUpgradeCacheQueue(currentPhase)` now also runs 8s after Viewer init (the queue is PERSISTENT in db.global and carried stale upgrade lookups across sessions).
- **P5.4 Drag ghost, definitive**: window OnDragStart hides all pool rows; OnDragStop's existing UpdateRows restores. (The P4 anchor fix was necessary but insufficient - some child rects still went stale on the first drag.)
- **P5.5 Square vendor icons**: `vendorIconTex` now SetPoint CENTER + SetSize(20,20) + SetTexCoord(0.07..0.93) instead of SetAllPoints.
- **P5.6 Frames named for /framestack**: rows = LootCollectorViewerRow{i}, icon frames = LootCollectorViewerRowIcon{i} / RowVendorIcon{i}. The user's stray-icon fstack showed an anonymous level-81 MEDIUM frame; with names, the next report identifies it exactly.
- **P5.7 Traffic meter scoped to the LC channel** (select(9,...) == Comm.channelName) and the minimap tooltip is sharing-aware ("Sharing: disabled" / "Public channel sync: off" instead of a meaningless msgs/min).
- **P5.8 Hide Bags in the Viewer**: mainFilter drops equipLoc INVTYPE_BAG when db.char.mapFilters.hideBags; hash entry "hidebags:1"; Settings toggle refreshes the viewer and is relabeled "map & list".
- **P5.9 /lcvendor diagnostic** in Detect.lua (defined AFTER GetSpecialVendorType for upvalue scope!): prints legacy/paused gates, unit, subname, rule match, merchant item count; clears the 10s NPC dedupe and force-runs OnNPCInteraction, reporting whether a vendor record was added. NOTE: GetNPCSubname rejects any subname containing digits - fine for the three current rules.

---

# FOURTH PASS (same day): field-test fixes

## P4.1 "Unknown link type" (Scanner/Toast/Viewer)
Vendor records carry synthetic negative item IDs (`-(300000+mapID)` etc.) whose links `SetHyperlink` rejects. Guards added:
- Scanner:GetItemData (anchor `-- Vendor pseudo-records use negative synthetic item IDs`): early-return for scanID <= 0 + pcall around SetHyperlink.
- Toast text OnEnter (anchor `-- Vendor pseudo-links carry negative item IDs`): plain vendor tooltip for negative-ID links, pcall otherwise.
- Viewer nameFrame OnEnter (anchor `-- Vendor records carry negative pseudo item IDs`): vendor tooltip short-circuit before the SetHyperlink chain.
INVARIANT: never SetHyperlink a link whose item ID is <= 0.

## P4.2 City vendors (the Ring Vendor mystery)
`Constants:IsForbiddenZone` treats capital cities as forbidden (with hardcoded exemptions only for the devs' own names). That silently blocked EVERY city vendor at multiple layers. Vendor-type records (dt == BLACKMARKET / vendorType set) are now exempt in:
- Core:HandleLocalLoot (anchor `isSpecialVendorDiscovery`) - forbidden-zone, StarterDBItemZones AND MS-vendor-deadzone gates
- DBSync:ApplyRecord (anchor `isVendorRecord`) - receive side; DBSync.Shares vendors loop - share side
- Map.lua: three IsForbiddenZone sites gated with `(not d.vendorType)`
- Viewer mainFilter + unique-values dataset: `not data.isVendor` exemption
NOTE: detection still requires the player to actually OPEN the merchant window (MERCHANT_SHOW).

## P4.3 Vendors tab drag ghost + stretched icons
Root cause: `vendorNameFrame` was two-point-anchored TOPLEFT/BOTTOMRIGHT to the vendorNameText FontString AND hit with `SetWidth` in UpdateRows -- an over-constrained rect; such frames go stale during window drags on this client (the whole name column visually stayed at the old screen position until the next UpdateRows re-anchor: "leaves the list behind, then snaps back"). Fixed: single-point anchor + explicit SetSize at creation, and ClearAllPoints+SetPoint+SetSize alongside every vendorNameText re-anchor in UpdateRows.
If a stray icon still appears, have the user hover it and run /framestack to name the frame.

## P4.4 CoA relic purge
CoA realms removed Librams/Idols/Totems. Relic rows (equipLoc INVTYPE_RELIC) are now excluded on CoA at: Viewer mainFilter (both discovered and undiscovered -- evaluated per refilter so rows vanish as soon as item data arrives), unique-values dataset, and GetUndiscoveredCount's cache branch (badge consistency). The old build-time skip (base-ID eqLoc check for undiscovered) remains.

## P4.5 Cache queue hygiene + stable label
- `Viewer:PruneStaleUpgradeCacheQueue(newPhase)` (called from the phase menu before PrewarmActivePhaseUpgrades): removes queued upgrade-variant lookups that don't belong to the newly selected phase, syncing Core._queueSet and resetting cacheQueueMax.
- The caching label classifies a 40-entry SAMPLE of the queue ("Items & Upgrades" when mixed) instead of the head only (which flickered).

## P4.6 Minimap tooltip live status + traffic meter
- Comm's CHAT_MSG_CHANNEL handler increments a rolling per-minute counter (`Comm._trafficCount/_trafficWindowStart/_trafficLastRate`) - two arithmetic ops per message.
- MinimapButton OnEnter appends: caching queue size, channel msgs/min, outgoing share queue depth.

---

# THIRD PASS (same day): StarterDB v7.0 regeneration

## P3.0 What was done
`LootCollector_StarterDB/db.lua` regenerated from the user's live SavedVariables, MERGED with the previous v6.8 payload (dev-curated entries preserved; existing records win on GUID collision). TOC Version and data.version both set to **v7.0** (they were mismatched before: TOC v6.7 vs data v6.8 — note the fresh-install path stores `dbData.version` into `profile.offeredOptionalDB` while the existing-install popup compares the TOC's `GetAddOnMetadata` version, so these MUST stay equal). `L.Version` in LootCollector.lua bumped to "beta-0.8.9s" (was still "beta-0.8.9r"; it feeds the comm `av` field and export metadata).

## P3.1 Format facts (verified by decoding the old file with the addon's own libs)
- Envelope: `"!LC1!" .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(AceSerializer:Serialize(payload), {level=8}))`.
- Payload: `{ meta = {v=1, addon, ts, realm, counts}, discoveries = {[guid]=LONG-KEY record}, blackmarketVendors, overlays=nil, profilesharing, tombstones, aoeTombstones }` — long-key records per `ImportExport.longKeyRecordFromShort` (guid/continent/zoneID/instanceID/itemID/coords{x,y}/itemLink/.../fp_votes/vendor*).
- Old v6.8 contents: 1,658 discoveries (1,573 WF dt=1 + 85 Mystic Scroll dt=2), 10 vendors, tombstones + aoeTombstones + (empty) profilesharing, meta.realm = "Bronzebeard - Warcraft Reborn", foundBy_player/fp_votes retained.
- StarterDB auto-import bypasses the realm gate (`ApplyImportString` detects `importString == LootCollector_OptionalDB_Data.data`); CoA-incompatible records (MS + relic subtypes) are skipped AT IMPORT for CoA realms, so shipping MS records is safe.

## P3.2 New v7.0 contents
- 4,524 discoveries (old 1,658 + 2,866 from the user's three realm buckets: Bronzebeard 1,979 / CoA 74 / CoA Beta 813), 16 vendors (10 + 6), covering 1,600 unique WF items.
- Records filtered: must have guid + itemID + zoneID + non-zero coords. profilesharing deliberately set to nil (never ship block/white lists). Dev tombstones/aoeTombstones carried over VERBATIM; the user's personal deletedCache was NOT merged (moderation stays curated).
- meta.realm kept as "Bronzebeard - Warcraft Reborn" so a manual paste of the string still passes the realm gate for main-realm users.

## P3.3 Safety verifications performed offline
1. Round-trip decode of the new string with the addon's libs: counts match, 500-record float spot-check — coords bit-identical (AceSerializer floats go through frexp/ldexp; power-of-two scaling is exact).
2. **Zone-lookup SUPERSET check: PASS** — `StarterDBItemZones` derived from the new payload contains every (itemID, zoneID) pair of the old one. This matters because Core/Viewer hygiene DELETES discoveries whose zone isn't in that lookup; a narrower regeneration would have pruned other players' records.
3. Shipped db.lua re-loaded from disk and decoded end-to-end (v7.0, 4,524, changelog string intact). CRLF preserved. `luac -p` clean.

## P3.4 Regeneration tooling
The generator harness ran under system Lua with WoW-API shims: string/table/math global aliases, `wipe`, `LibStub:NewAscensionLibrary(major)` aliased to `NewLibrary(major, minor or 1)` (Ascension's client extends LibStub; minor is optional there), and **math.frexp/ldexp polyfills for Lua 5.4** (removed from 5.4; AceSerializer needs both). If you regenerate again: merge, don't replace — and re-run the superset check before shipping.

---

# SECOND PASS (same day): item accuracy, vendor discoveries, UI polish

## P2.0 SavedVariables audit (data facts — trust these)
Analyzed the user's live 11 MB SavedVariables (3 realm buckets: "Bronzebeard - Warcraft Reborn" 1921 unique item IDs, "Vol'jin - Conquest of Azeroth" 1538, "Vol'jin - CoA Beta" 1536):
- **1,585 / 1,838** Worldforged-list items have at least one discovery record in SOME bucket; **253 are truly undiscovered everywhere** (list with names: `truly_undiscovered_items.csv`, generated from AtlasLoot comments).
- Per-bucket undiscovered counts: 280 / 315 / 316 — the viewer's per-bucket "Undiscovered" number is CORRECT by design (realm buckets are deliberately separate); ~63 items undiscovered on the beta bucket are known on other buckets.
- **314 items were flagged [NEW] in db.global.newWorldforgedItems; 61 of them already had discovery data** → root cause: the flag was write-once (single write site, no clear). Discovery `i` fields in the live DB are already base IDs (Core remaps on ingest).

## P2.1 NEW-flag lifecycle (Core.lua)
- Anchor `-- NEW-flag lifecycle:` in `Core:AddDiscovery` — flag cleared when any discovery of that (base) item lands.
- Anchor `-- Stale-flag sweep (every login):` in `PerformOnLoginMaintenance` — prunes flags for items discovered in ANY realm bucket (`db.global.realms[*].discoveries`), normalized via `GetBaseItemID`. Runs every login, not just first init.

## P2.2 Untagged vanity Worldforged items (Detect.lua + LootCollector.lua)
- New `LootCollector:IsWorldforgedListItem(id)` (lazy set from WorldforgedList, base-normalized) in LootCollector.lua.
- `Detect:IsWorldforged(link)` short-circuits TRUE for curated-list items before the tooltip tag scan (anchor `-- Curated-list override:`). Fixes Frightened Kitten (354157)–type items never turning Discovered on loot. The `src` gate is untouched: WF discoveries still require `world_loot`.

## P2.3 Vendor discoveries re-enabled (Detect/Core/Comm/Constants)
Recon findings (verified): detection & local DB write were INTACT; `Core:HandleLocalLoot`'s vendor branch returned before any broadcast/toast/UI-message; `EnqueueOutgoingSync` whitelists DISC/CONF only; the SHOW wire is the only shape carrying vendor fields; legacy "EX"/"RING" vendorTypes survive in Viewer labels/icons + Core repair pass.
- **Detect.lua**: `SPECIAL_VENDOR_SUBNAMES` table (case-insensitive find): "blackmarket artisan supplies"→BM, "exquisite collectables"→EX, "ring vendor"→RING. `vendorType = isMSVendor and "MS" or specialVendorType`. EX/RING pseudo-itemID falls into the existing `-(500000+mapID)` "[Specialty Vendor]" branch; GUID prefixes EX-/RING- are already understood by the repair pass and Viewer.
- **Core.lua** vendor branch (anchor `-- RE-ENABLED: local vendor detection used to end here silently`): fires `LootCollector_DiscoveriesUpdated` + `Toast:Show` (pcall-guarded) + `Map.cacheIsDirty` for NEW records; calls `Comm:QueueVendorAutoShare(recordToBroadcast)`.
- **Comm.lua** (anchor `=== Vendor auto-share (throttled) ===`): `QueueVendorAutoShare` — persistent daily cap `db.global.vendorAutoShare = {day, count}` (max 1/day), per-record `lastAutoShared` (7-day min), 5–30 s random delay. `BroadcastVendorDiscovery` — reuses `_buildWireV5_SHOW` (the proven vendor-carrying shape), overrides `op = "VEND"`, adds `s` (old-client validation requires it on non-SHOW ops) and `mid` (enables dedupe), caps `vendorItemIDs` at 25, sends via `_enqueueChannelWire` (NOT EnqueueOutgoingSync — that queue is DISC/CONF-only by design; both functions are defined AFTER the `_enqueueChannelWire` local so the upvalue resolves).
- **Comm.lua RouteIncoming**: new `elseif tbl.op == "VEND"` branch (after GFIX): `_shouldDropDedupe(mid,"VEND")` → build vendData (SHOW-shaped) → `Core:AddDiscovery(vendData, {isNetwork=true, op="VEND"})` → existing `_ProcessVendorDiscovery` handles rehydration/toast/UI. Old clients: VEND passes their generic validation and falls through their op chain — no popup, no error (worst case a bare vendor pin).
- **Constants.lua**: `ALLOWED_DISCOVERY_TYPES[BLACKMARKET] = true` now explicit (was nil-by-omission; only `== false` gates let it through before — fragile vs truthiness-gate refactors).

INVARIANTS: never route vendor auto-share through `EnqueueOutgoingSync` without extending its op whitelist; never remove `w.s`/`w.mid` from the VEND wire; keep VEND out of the SHOW consent-popup path.

## P2.4 Vendors tab inline-only (Viewer.lua + Settings.lua)
- `ApplySettings`: `self.inlineVendorView = true` forced (+ profile write-through). Settings.lua: profile default forced true; the "Use Inline Vendors Style" checkbox is `hidden = true`. The split-pane (`vendorInventoryFrame`/`splitterBar`, `GetMainScrollHeight` 0.64 ratio branch, `UpdateLayout` split branch) is now unreachable — retired, not deleted. This also removes the window-drag visual glitch on the Vendors tab (split pane was the artifact source); if a stray icon still appears after this, suspect Map's `_hoverBtn` or a Toast icon next.

## P2.5 Small UI (Viewer.lua)
- Worldforged phase menu toggles closed on re-click (anchor `-- Toggle behavior:`, checks `UIDROPDOWNMENU_OPEN_MENU == Viewer._worldforgedPhaseMenuFrame`).
- Caching bar now classifies the queue head (anchor `-- Tell the user WHAT is being cached`): "Caching Phase Upgrades / Worldforged Items / Items: X / Y (Z%) - server lookups, safe to play".

---

This document describes EVERY change made in the 0.8.9r → 0.8.9s pass, with root causes,
code anchors you can grep for (line numbers shifted, so search for the quoted strings),
invariants that must not be broken by future edits, and the items deliberately left alone.

Files touched:
1. `Modules/Viewer.lua` — 13 changes (phase bug, cache builder, filters)
2. `LootCollector.lua` — 3 changes (profiler default, /lcprofiler, memoization)
3. `Modules/Comm.lua` — 4 changes (memory leak, flood fast-path, debug guards)
4. `Modules/Core.lua` — 1 change (O(n) scan gate)
5. `Modules/WorldforgedUpgrades.lua` — 6 recovered data rows
6. `LootCollector.toc` — version bump + title color fix
7. `CHANGELOG.md` — user-facing 0.8.9s section
8. `README_FABLE.md` — handshake summary section

All edited Lua files pass `luac -p`. All files keep their CRLF line endings.
No retail-era APIs were introduced: only stock 3.3.5a API plus Ascension extensions
already used in this codebase (`C_Timer.After`, `RETRIEVING_TEXT`, etc.). Lua 5.1 only.

---

## 0. Root cause of the reported bug (undiscovered Worldforged items removed when a phase is selected)

Two cooperating defects in `Modules/Viewer.lua`:

**(a) The veto.** In the cache-build row loop (`ProcessCacheBuildChunk`), rows synthesized
from `L.WorldforgedList` (`entry.isUndiscovered`) were dropped when a tooltip scan of the
row's CURRENT `itemLink` said "not Worldforged":

```lua
-- OLD CODE (removed):
if entry.isUndiscovered and itemLink and not isWorldforged then
    skipItem = true
end
```

With an upgrade phase active, `itemLink` at that point holds the **upgraded variant's**
link (the ID was swapped earlier in the loop), so the check was evaluated against the
wrong item entirely.

**(b) The fragile detector.** The local `IsWorldforged(itemLink)` scanned only tooltip
lines **2–5**, had no "Retrieving item information" guard, and **permanently cached
negative results** per link in `Cache.worldforged` (never pruned during a session).

**Timing chain that made it look random:** while the upgraded item was uncached,
`GetItemInfo` returned nil → no link → the row was kept ("assume true"). The addon then
queued the upgrade IDs for cache-warming itself (`PrewarmActivePhaseUpgrades` +
`QueueItemForCaching`). Once the data arrived, the NEXT full rebuild (phase switch,
reopen, data-count change) re-ran the veto against the now-cached upgraded tooltip,
failed, and silently deleted the rows. Discovered rows were immune (the veto was
undiscovered-only) — hence "it removes the new and undiscovered Worldforged items".

---

## 1. Modules/Viewer.lua

### 1.1 `IsWorldforged()` hardened
Anchor: `local function IsWorldforged(itemLink)` (~line 538).
- Now scans **all** tooltip lines (`for i = 2, numLines`), matching Scanner.lua's behavior.
- New guard BEFORE scanning/caching: if `NumLines() < 2`, or line 1 is nil, or line 1 ==
  `RETRIEVING_TEXT`, return `false` **without writing to `Cache.worldforged`** — a partial
  tooltip must never poison the session cache.
- Each line fontstring is nil-checked (`local lineObj = _G[tooltipName .. i]`).

INVARIANT: never cache a negative result from an incomplete tooltip.

### 1.2 Undiscovered veto removed; WF status judged from BASE item
Anchor: `-- Rows synthesized from the curated WorldforgedList are` (~line 1862).
New logic in the row build:

```lua
if entry.isUndiscovered then
    isWorldforged = true          -- curated list ⇒ Worldforged by definition
elseif not isWorldforged then     -- only if Scanner didn't already say true
    local baseLink = discovery.il
    if (not baseLink or baseLink == "") and discovery.i then
        baseLink = select(2, GetItemInfo(discovery.i))
    end
    if baseLink and baseLink ~= "" then
        isWorldforged = IsWorldforged(baseLink)
    end
end
```

- The `skipItem = true` veto block is deleted. Remaining `skipItem` sites are intentional:
  CoA relic filter (undiscovered relics on CoA realms) and discovered-row data hygiene
  (0,0 coords / StarterDB zone mismatch / forbidden zones).
- Note the old code could OVERRIDE Scanner's positive `itemData.isWF` with the fragile
  tooltip check; the new code only consults the tooltip when Scanner said false/unknown.

INVARIANT: rows sourced from `L.WorldforgedList` must NEVER be removed by heuristics.
The list is dev-curated (verified identical to AtlasLoot's `WorldforgedClassic`, 1838/1838).

### 1.3 Base-item metadata fallback while upgrade data is in flight
Anchor: `-- Phase-upgrade data still in flight: borrow the base item's` (~line 1902).
Placed immediately after the `GetItemInfoSafe(itemLink, itemID)` call in the row build:
if `name` is nil AND `itemID ~= discovery.i` (i.e. a phase swap happened), pull
`GetItemInfo(discovery.i)` and fill `itemLevelVal/minLevel/itemTypeVal/itemSubTypeVal/equipLocVal`
(only where nil) and replace an "Unknown Item (id)" `itemName` with the base name.
- Rows stay searchable/filterable instead of rendering "Unknown Item" with empty columns.
- `self.hasUncachedData = true` was already set earlier in the "Unknown Item" branch, so
  the reload-hint/debounced-rebuild machinery still arms.
- The row still heals to UPGRADED data via `GET_ITEM_INFO_RECEIVED` (matched on
  `row.displayItemID`), which overwrites these fallback fields.
- Deliberately does NOT pass the base link into `GetItemInfoSafe` — that would poison
  `Cache.itemInfo[upgradedID]` with base data.

### 1.4 Base IDs queued for caching alongside upgrade IDs
Anchor: `-- Also warm the BASE item when displaying an upgraded phase` (~line 1993).
After the existing `QueueItemForCaching(itemID)`, also queue `discovery.i` when it
differs and is uncached. Needed by 1.3, `row.sortQuality` (reads base quality), and
undiscovered-row tooltips.

### 1.5 `UpdateAllDiscoveriesCache` rewritten as a forcing wrapper — THE ASYNC BUILDER WAS DEAD
Anchor: `-- FIXED: this entry point used to fill a local scanQueue that` (~line 1668).

The old body filled the **file-local `scanQueue`** with entries shaped
`{ guid=, discovery=, type= }` and then called `ProcessScanQueueBatch()` →
`ProcessCacheBuildChunk()` — which reads **`self._cacheBuildQueue`** with entries shaped
`{ guid=, d=, isVendor= }`, and `self.scanProgressCallback` (the old body set the LOCAL
`scanProgressCallback` instead). Three mismatches; the two build paths were never
compatible. Every "async" rebuild ran against an empty/wiped `_cacheBuildQueue` and
instantly completed with an EMPTY cache marked `discoveriesBuilt = true`.

Affected callers: `PrewarmCache` (12s after login), `/lcviewer rebuild`, delete-player
flow, Block & Purge flow. Masked partially by `HasDataChanged()` returning true on its
first call and by comm traffic clearing `discoveriesBuilt`, which is why it looked like
random flakiness rather than a hard failure.

New body (complete):
```lua
function Viewer:UpdateAllDiscoveriesCache(onCompleteCallback)
    VDebug("UpdateAllDiscoveriesCache: delegating to chunked builder")
    if Cache.discoveriesBuilding then
        if onCompleteCallback then
            self.scanProgressCallback = onCompleteCallback  -- adopt, don't restart
        end
        return
    end
    Cache.discoveriesBuilt = false   -- force past the built-guard in ...CacheSync
    Cache.lastFilterState  = nil
    Cache.filteredResults  = {}
    self:UpdateAllDiscoveriesCacheSync(onCompleteCallback)
end
```

- `UpdateAllDiscoveriesCacheSync` (despite its name, chunked/async via `C_Timer`) is now
  the ONLY builder.
- `ProcessScanQueueBatch`, and the locals `scanQueue`/`scanCursor`/`scanProgressCallback`
  (declarations + reset sites in `ClearCaches`/`Hide`), are now vestigial. Safe to leave;
  do not resurrect the old dual-queue pattern.
- Restart-while-building is deliberately NOT done (chunk cursor corruption); the wrapper
  adopts the completion callback instead.

### 1.6 `RefreshData` clears the built flag before rebuilding
Anchor: `-- UpdateAllDiscoveriesCacheSync refuses to run while discoveriesBuilt` (~line 6480).
`UpdateAllDiscoveriesCacheSync` has a guard: `if Cache.discoveriesBuilt or
Cache.discoveriesBuilding then return end`. RefreshData could decide
`shouldRebuildCache = true` due to `dataHasChanged` while `discoveriesBuilt` was still
true → the builder silently skipped AND the callback never ran (stale view). Now
`Cache.discoveriesBuilt = false` is set just before the call in that branch.

### 1.7 Undiscovered-placeholder dedup normalizes to base IDs
Anchor: `-- Normalize to the BASE item ID so a discovery recorded under an` (~line 1743).
`discoveredItemIDs[L:GetBaseItemID(discovery.i)] = true` (was raw `discovery.i`).
Prevents a phantom "undiscovered" placeholder when the player's discovery was recorded
under an upgraded/scaled variant ID. `GetUndiscoveredCount()` already normalized this
way; the grid builder didn't — they now agree.

### 1.8 `GetFilterStateHash`: flat column filters + phase now hashed
Anchor: `local FLAT_FILTER_KEYS = ` (~line 2487).
`Viewer.columnFilters` mixes two shapes:
- double-nested: `eq = { slot={v=true}, type={...}, class={...} }`, `ms = { class={...} }`
- FLAT: `zone/source/quality/looted/vendorType = { value = true }` directly.

The old hash loop assumed double nesting, so for flat filters the inner `values` was a
boolean and `type(values) == "table"` was always false → **zone/source/quality/vendorType
never contributed to the hash** → `Cache.filteredResults` could be served stale after
changing them (visible via any refresh path that doesn't manually nil
`Cache.lastFilterState`, e.g. `OnGetItemInfoReceived → RefreshData`).
New loop special-cases `FLAT_FILTER_KEYS = { zone, source, quality, looted, vendorType }`.

Also appended `"wfphase:" .. worldforgedPhase` to the hash as a backstop. NOTE: the phase
menu (`OpenWorldforgedPhaseMenu`) still MUST clear `Cache.discoveriesBuilt` on change —
the item-ID swap happens at BUILD time, not filter time; the hash entry only protects the
filter cache.

INVARIANT: any new filter dimension must be added to `GetFilterStateHash` (use the flat
branch if it's a flat map).

### 1.9 Sort comparator: `vendorType` / `price` / `continent` branches added
Anchor: `elseif self.sortColumn == "vendorType" then` (~line 2440).
The Vendors tab defaults to `sortColumn = "vendorType"` and its headers can set `"price"`
and `"continent"`, but the comparator had no branches for them → all three fell to the
`else` branch = ordering by internal `guid` while the header showed an active sort arrow.
- `vendorType`: sorts by `row.sortType` ("BM"/"MS"), ties broken by `sortName`.
- `price`: sorts by `sortName` — vendor LIST rows carry **no** price field (the Price
  column exists in the vendor-inventory side panel, per-item). Wiring a real price sort
  needs a design decision (e.g. precompute cheapest inventory item at build time).
- `continent`: `tostring(discovery.c) .. "|" .. zoneNameStr` (groups by continent, then zone).

### 1.10 Pagination clamp
Anchor: `-- FIXED: clamp the current page whenever the result set shrinks` (~line 2620).
In `GetPaginatedDiscoveries`, `currentPage` is clamped to `[1, totalPages]` right after
`totalItems` is known. Fixes blank grids when the result set shrinks through paths that
don't reset the page (the Refresh button after comm data arrived; unfavoriting the last
item on the last page).

### 1.11 Favorites filter fixes (three sites)
- Toolbar "Clear" button and dropdown "Clear All Filters": both now do
  `Viewer.favoritesFilterState = nil` (it was the ONLY filter neither reset — the list
  stayed favorites-only and `HasActiveFilters()` kept the Clear button lit forever).
  The dropdown clear also gained `Viewer.columnFilters.vendorType = {}` (the toolbar
  already had it; the two handlers had drifted).
  Anchors: `-- FIXED: Favorites was the only filter "Clear All" forgot,` and
  `-- FIXED: Favorites was the only filter this Clear button forgot,`.
- Star-icon OnClick: when `favoritesFilterState` is active, unfavoriting now nils
  `Cache.filteredResults/lastFilterState` before `RefreshData()`. The hash can't see
  favorites CONTENT changes (only the toggle), so the cached list was reused and the
  unfavorited row stayed visible.
  Anchor: `-- FIXED: the filter-state hash cannot see favorites`.

### 1.12 Undiscovered rows participate in dropdown option building
Anchor: `-- FIXED: mirror mainFilter's guard -- undiscovered placeholder` (~line 889).
`GetFilteredDatasetForUniqueValues` ran `Constants:IsForbiddenZone(c, z, fp)` on every
row; undiscovered placeholders live at `c=0, z=0`, which IsForbiddenZone treats as
forbidden → they were excluded from the datasets that build slot/type/class/zone dropdown
options. Now guarded with `not data.isUndiscovered`, mirroring `mainFilter`.

### 1.13 Deep Search checkbox no longer forces a full cache rebuild
Anchor: `-- PERF: this used to force a full chunked rebuild of the entire` (~line 3988).
`tooltipCheck` OnClick did `Cache.discoveriesBuilt = false` (thousands of rows rebuilt)
to flip a flag read only by the search predicate. Now it just clears
`Cache.filteredResults` + `Cache.lastFilterState`. Row `tooltipText` is populated during
cache build regardless of the checkbox, so this is safe.

---

## 2. LootCollector.lua

### 2.1 Profiler defaults OFF
Anchor: `-- PERF: profiler now defaults OFF.` (line ~15).
`LootCollector._profilerEnabled = false` (was `true`). The `ProfileStart/ProfileStop`
pattern wraps nearly every function in the comm/core hot path (2 × `debugprofilestop()`
+ stats bookkeeping per call, 10–14 profiled calls per incoming channel message ⇒
~1,700–5,600 timer calls/sec at 5–11k msgs/min). All ~200 call sites already guard with
`L.ProfileStart and L:ProfileStart()` / `if pTime then`, so flipping the default
short-circuits everything with zero call-site edits.
Consumers verified safe with empty stats: ImportExport debug payload, Settings.lua reads.

### 2.2 New `/lcprofiler` slash command
Anchor: `SLASH_LCPROFILER1` (end of file). Subcommands: `on | off | report | reset`.
`report` prints the top 15 functions by total ms (name, total, calls, max).

### 2.3 `IsWorldforgedUpgradeable` memoized
Anchor: `-- Memoized: this runs inside map/minimap pin refresh loops` (~line 1738).
Result cached in `self._wfUpgradeableMemo[baseID]`, but ONLY once `GetItemInfo(baseID)`
returns data — uncached items fail open (upgradeable) and stay re-checkable so bags get
excluded correctly when their data arrives. Map/minimap pin loops called this per pin per
refresh, each costing a `GetItemInfo` (a server query when uncached).
NOTE: the 12th `GetItemInfo` return (`classID`) is not a stock-3.3.5 return; it was in
the pre-existing code and is kept harmlessly (nil ≠ 1) — the `INVTYPE_BAG` equipSlot
check (return 9, valid 3.3.5) is what actually excludes bags.

---

## 3. Modules/Comm.lua

### 3.1 MEMORY LEAK: dedupe table was never pruned
Anchor: `-- FIXED: this read "Comm.seen" -- a field that is never assigned` (in `pruneCaches`).
`pruneCaches()` read `local mSeen = Comm.seen` — a field that is never assigned anywhere
(the real table is `Comm._seen`, written by `_shouldDropDedupe`). The prune block was
permanently dead, so every unique `mid.."_"..op` key accumulated for the whole session.
Under 5–11k msgs/min this is the "gets heavy and stays heavy until /reload" symptom.
Fixed to `Comm._seen`. Also added pruning of `Comm._senderInjectionRates` (entries whose
`resetAt` is >600s stale) in the same sweep.

### 3.2 Early duplicate drop (flood fast-path) — READ-ONLY BY DESIGN
Anchors: `local function _isRecentDupe(mid, op)` and
`-- PERF (flood path): duplicate DISC/CONF payloads` (in `RouteIncoming`).
New helper `_isRecentDupe` checks `Comm._seen` WITHOUT writing. `RouteIncoming` calls it
for `op == "DISC" or CONF` right AFTER the spam-sentinel block and before the GFIX/ADCM
branches, item-name lookups, injection-rate bookkeeping and `_normalizeForCore` (a
~20-field table alloc + possible `GetItemInfo` per message).

Placement rationale (do not move it):
- AFTER the spam sentinel: the sentinel counts repeated mids per sender
  (`_trackSpam[sender][mid]`) to flag spammers; dropping duplicates before it would
  neuter that detection. The ingress dedupe (`sender|op|mid`, TTL 8s) only catches
  same-sender repeats within 8s, so the sentinel relies on seeing slower repeats.
- READ-ONLY: the authoritative `_shouldDropDedupe(norm.mid, norm.op)` further down is
  still the single WRITER of `Comm._seen`. If you make the early check record, the late
  check will see the just-written key and **drop every first-time message**. Never do that.
- Scoped to DISC/CONF: ACK/CORR/SHOW/GFIX/ADCM return through their own branches before
  the late dedupe today; scoping preserves their exact semantics.

### 3.3 Hot-path debug strings guarded
Anchors: `-- PERF: only build the debug strings when chat-debug is actually on.`
(RouteIncoming) and `-- PERF: build debug strings only when chat-debug is on`
(`_ProcessChatMsg`, which now has a `local cdebugOn = ...` used twice).
`L._cdebug(module, msg)` checks the flag INSIDE the function, but Lua evaluates arguments
eagerly — the three per-message call sites (`"Routing parsed payload..."`,
`"Processing plausible chat message..."`, `"Regex matched header..."`) each allocated a
formatted string per message with the flag off. Now wrapped in
`if L.db.profile.cdebugMode` checks. The other ~49 `_cdebug` sites are on cold paths and
were left as-is.

---

## 4. Modules/Core.lua

### 4.1 `AddDiscovery` zone-correction scan gated (was O(n) per accepted message)
Anchor: `-- PERF: this zone-correction scan used to iterate the ENTIRE discoveries`.
The Teldrassil/Ashenvale fixup loop scanned the whole discoveries DB (cap 10,000 rows)
on EVERY accepted discovery. Derivation of the gate: the correction applies only when
`getPreferredZone(existing.z, z)` returns `incorrectZ == z` (the INCOMING zone must be
the "incorrect" member of a pair). From its branches, the only possible such incoming
zones are **41** (Ashenvale-pair) and **242 / 122** (Teldrassil-pair). The scan now runs
only `if zNum == 41 or zNum == 242 or zNum == 122`. Behavior for those zones unchanged;
all other zones skip straight past. If the dev team ever extends `getPreferredZone` with
new pairs, THE GATE SET MUST BE EXTENDED to include the new "incorrect" zone IDs.

---

## 5. Modules/WorldforgedUpgrades.lua

### 5.1 Six recovered rows (data bug inherited from AtlasLoot itself)
Anchor: `-- Recovered rows: these six entries are syntactically broken in` (end of table).
In AtlasLoot's `AtlasLoot_Cache/ItemIDsDatabaseFixes.lua` (lines ~1957–1962), six entries
are written as:

```lua
ItemIDsDatabaseCorrectedIDs[1262811] = nil,nil,nil,{0,1379865,1381865,1383865,1385865,1387865}
```

Lua assigns only the FIRST value of the expression list to a single variable target —
this stores `nil` and discards the table. The original export to LootCollector therefore
silently skipped them. Reconstructed with the wrapped table occupying columns 4–9
(Dungeon/ZG/T1/T2/AQ/T3), a leading `0` meaning "no dungeon upgrade" → `nil`:
`1262811, 2088888, 3595662, 4050651, 4050652, 4050653`.
This should ALSO be reported/fixed upstream in AtlasLoot.

Validation: standalone harness (13/13 assertions) covering standard rows, recovered rows,
sparse fallback-to-base, reverse mapping (`GetBaseItemID`), and phase-0 identity.

---

## 6. LootCollector.toc
- `## Version: beta 0.8.9r` → `beta 0.8.9s`
- Title: `|ce5cc80ffLootCollector|r` → `|cffe5cc80LootCollector|r` — WoW color escapes are
  `|cAARRGGBB`; the old value had RGB+alpha swapped, tinting the addon-list title wrong.
  The `[beta.0.8.9s]` suffix was bumped in the Title too.

---

## 7. Data architecture facts (verified this pass — trust these)

- `Modules/WorldforgedUpgrades.lua` is an export of AtlasLoot's
  `ItemIDsDatabaseCorrectedIDs` (1971/1972 rows byte-identical pre-fix).
- `Modules/WorldforgedList.lua` == AtlasLoot `WorldforgedClassic` list, 1838/1838.
- Column semantics (AtlasLoot difficulty indices): 1=Bloodforged, 2=Heroic Bloodforged,
  3=Base (always nil in rows — the key IS the base), 4=Dungeon upgrade (P0),
  5=ZG (P1), 6=T1/MC (P2), 7=T2/BWL (P3), 8=AQ (P4), 9=T3/Naxx (P5).
- `viewer.worldforgedPhase` ∈ 0..6 (0=Base, 1..6 = P0..P5);
  `GetWorldforgedPhaseItemID` maps via `upgrades[phase + 3]`, nil → base fallback.
- **489 of 1838** WF items have NO Dungeon/P0 upgrade **by design** (high-level bases
  start upgrading at ZG); 1349 have full 6-phase chains; 0 other gap patterns remain.
  At P0 those 489 show base item + no ▲ arrow. This is correct behavior, not a bug.
- A handful of raid-tier rows (10904, 16xxx, 22489…) in WorldforgedUpgrades use the RAID
  difficulty layout (4=Heroic, 5=Mythic, 6=Ascended) — they are NOT in WorldforgedList
  and are effectively inert for the phase feature; left untouched.

---

## 8. Deliberately NOT changed (do not "fix" without a reason)

- `AddDiscoveryToCache` / `RemoveDiscoveryFromCache` are intentional no-op stubs; live
  comm updates with the window open only bump `pendingUpdatesCount` → "Refresh (N)"
  button. Sound debounce design; do not wire per-message cache mutations back in.
- Duplicate `Viewer:Hide()` definitions (~7080/~7110); the later wins and also aborts
  in-flight chunked builds (`Cache.discoveriesBuilding = false`) — acceptable.
- `columnFilters.looted` dropdown-shaped filter has no UI entry point (superseded by the
  tri-state cycle button) — dead but harmless.
- `context.currentFilter == "msv"` branch in unique-values — dead code, harmless.
- `GetCascadedFilterContext` ignores min/max level, favorites, looted cycle state, deep
  filters, phase — dropdown options can be "too broad" (never too narrow). Low severity,
  left for a future polish pass.
- Vendors-tab "price" sort = name fallback (see 1.9) pending a real per-row price value.
- `UpdateSortHeaders` doesn't color/arrow the Continent header (cosmetic).
- Profiler instrumentation call sites all left intact — only the default flag flipped.

---

## 9. Testing status & in-game checklist

Done here: `luac -p` on all edited files; 13/13 phase-lookup harness assertions;
zip verified (no `.bak*` shipped, 92 entries).

Pending in-game (user runs these):
1. `/lcv` → Worldforged tab → select `Phase 1: Zul'Gurub` → undiscovered items must stay;
   Undiscovered count must not drop; names may briefly show base data, then heal with ▲.
2. Cycle phases, `/reload`, reopen — no items may vanish across rebuilds.
3. `/lcviewer rebuild` — must repopulate the list (previously: empty until data drift).
4. Favorites: enable filter → Clear button → everything resets including Favorites.
   Unfavorite a row while filtered → row disappears immediately.
5. Vendors tab → rows grouped by type by default; Type/Continent headers reorder sensibly.
6. Long session in a crowded hub → memory should plateau (was: unbounded growth).
7. Optional tooltip dump for any upgrade ID (run twice if empty — first call queries server):
   `/run local t=CreateFrame("GameTooltip","LCT",UIParent,"GameTooltipTemplate")t:SetOwner(UIParent,"ANCHOR_NONE")t:SetHyperlink("item:1378061")for i=1,t:NumLines()do print(i..": "..(_G["LCTTextLeft"..i]:GetText()or""))end`

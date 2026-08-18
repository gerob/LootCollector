# Tester checklist

Hand this to a tester. Reply with Pass / Fail / Skip per section.

If the map is empty after install: confirm **LootCollector_StarterDB** is enabled, then **Merge Starter**. Do not Override Starter.

If a pin looks wrong: zone name, item name, screenshot. No `/lcdiag` unless asked.

## Setup

1. Install this build. Type `/reload`.
2. Write down your **realm** and the **version** (Discoveries, hover top-left).
3. Play with the map closed until you start a check.

---

### 1. Version / load

- **Do:** Open Discoveries. Hover the version (top-left). Check the minimap button tooltip.
- **Expect:** Same build number in both places. No red Lua errors in chat.

- **Do:** Type `/lcvendor`.
- **Expect:** It runs (vendors window or a status line). No error.

### 2. Map

- **Do:** `/reload` with the map closed. Open the world map.
- **Expect:** Pins appear. Map is not endlessly blank or flickering.

- **Do:** Keep the map open and change zones.
- **Expect:** Pins update. No long freeze.

- **Do:** Look at the world-map title bar and the minimap button.
- **Expect:** Title bar shows a **LootCollector** button (left of shrink/expand; left of Mapster if present). Minimap still uses the LC icon. The title-bar button cannot be dragged.

### 3. Discoveries and Filter Map

- **Do:** Open Discoveries. Type a name (example: Fenris) and Add/Enter.
- **Expect:** A chip appears. The list shrinks.

- **Do:** Add a second chip. Remove one with X. Clear.
- **Expect:** List shrinks more, then returns to normal.

- **Do:** Set a filter. Click **Filter Map** On (gold). Look at world map and minimap. Turn Filter Map Off.
- **Expect:** Pins match the filtered list while On. Pins go back to normal when Off.

### 4. Looted

- **Do:** Loot a tracked item. Class and weapon type do not matter.
- **Expect:** That pin marks **looted** for this character.

- **Do:** Turn on hide looted.
- **Expect:** That pin is hidden.

- **Do:** `/reload`.
- **Expect:** Still looted on this character.

- **Do:** (Rexxar / Vol'jin only) Log the same character name on the other realm.
- **Expect:** Worldforged pins sit in the **same places**. Looted does **not** carry over.

### 5. Worldforged pickup

- **Do:** Pick up a Worldforged item from the world spawn (BoP Okay).
- **Expect:** The pin stays in that zone. It can show a stronger confirmation. It does not jump to another zone.

- **Do:** Later, loot that same item from bags or a mob.
- **Expect:** It only marks **looted**. The pin does not move.

### 6. Pause and arrow

- **Do:** Type `/lcpause`. Play 1–2 minutes. Type `/lcpause` again.
- **Expect:** Chat says paused. Gameplay feels normal. Second time resumes.

- **Do:** Turn on auto-track nearest unlooted. `/reload`.
- **Expect:** Auto-track starts again.

- **Do:** Use Arrow **Skip** and **Clear** under the TomTom arrow.
- **Expect:** Skip drops that pin for this session only. Clear wipes the skip list (or `/lcarrow clearskip`).

### 7. Fade, Enchant, Vendors

- **Do:** In Discoveries, click Fade: All / Hide / Only. If Filter Map is On, check the map too.
- **Expect:** The list (and map, if Filter Map is On) changes. No errors.

- **Do:** Look for the Enchant button (between Looted and Date).
- **Expect:** Hidden on Rexxar / Vol'jin (CoA). Shown on Bronzebeard / Area 52 (WR). If you see it, click All → Yes → No → All with no errors.

- **Do:** Open the Vendors tab.
- **Expect:** It opens. No error.

Skip unless asked: share/import, Report as Gone, Mystic Scrolls, CustomImport.

---

## Copy into Discord

```
LootCollector tester checklist
Install this build → /reload → write realm + version (Discoveries hover, top-left).

If the map is empty: enable LootCollector_StarterDB, then Merge Starter. Do not Override Starter.
Reply Pass / Fail / Skip per section.

1) Version / load
Do: Open Discoveries (left click Minimap icon), observe version (top-left). Check minimap tooltip has same version. Close window Type /lcv, window reopens.
Expect: Same build in both places. /lcvendor runs. No red Lua errors.

2) Map
Do: /reload with map closed, then open the world map. Change zones with map open. Look at the map title-bar **LootCollector** button and the minimap button.
Expect: Pins appear, no endless flicker. Pins update on zone change, no long freeze. Title-bar LootCollector button; LC icon on minimap only.

3) Discoveries and Filter Map
Do: Type a partial name (e.g. Blackrock) → Add/Enter → chip. Add a 2nd chip (e.g. stamina). Remove with X. Clear.
Expect: List shrinks, then returns to normal.
Do: Set a filter → Filter Map On (gold) → check world map + minimap → Filter Map Off.
Expect: Pins match the list while On. Pins back to normal when Off.

4) Looted
Do: Loot a tracked item (any class/weapon). Turn on hide looted. /reload.
Expect: Pin marks looted. Hide looted (map menu) hides it. Still looted after /reload on this character.
Do: (Rexxar / Vol'jin) same character name on the other realm.
Expect: Pins in the same places. Looted does not carry over.

5) Worldforged pickup
Do: Loot a Worldforged item and then kill a few mearby mobs, icon stays in proper spot and doesn't travel to where you killed the mob.
Expect: Pin stays in that zone (confirmation can go up). Bag/mob loot only marks looted; pin does not move.

6) Pause and arrow
Do: /lcpause → play 1–2 min → /lcpause again.
Expect: Paused, then resumes. 
Do: Open map, left click title-bar **LootCollector** → Arrow → Auto-track nearest unlooted → /reload. TomTom (must have installed) Arrow shows Skip / Clear beneath it. Arrow stays until loot (or Skip / Hide).
Expect: Auto-track starts again after /reload. Skip points arrow to next item, clear resets this, pointing to nearest item again.

7) Fade, Enchant, Vendors
Do: Fade All / Hide / Only. Look for Enchant (not on CoA realm). Open Vendors tab.
Expect: Fade changes the list (and map if Filter Map On). Enchant hidden on CoA (Rexxar / Vol'jin), shown on other realms. Vendors tab opens. No errors.

If a pin looks wrong: zone name, item name, screenshot.

Send back:
Realm:
Version:
1 Version/load:
2 Map:
3 Discoveries/Filter Map:
4 Looted:
5 WF pickup:
6 Pause/arrow:
7 Fade/Enchant/Vendors:
Notes / fails:
```

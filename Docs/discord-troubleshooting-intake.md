# Discord troubleshooting intake

Copy the **Paste into Discord** block below into a support channel or ticket thread. Bug reporting person fills it in and replies in-thread.

## Maintainer notes


| Field                    | Why it matters                                                                                     |
| ------------------------ | -------------------------------------------------------------------------------------------------- |
| Realm                    | Per-realm discovery DB; CoA vs WR vs Freepick vs Wildcard changes MS, relics, archetypes.          |
| Addon version            | Reproduce against the right build; stale installs cause sync/schema mismatches.                    |
| Symptom category         | Routes to map data vs filters vs freeze vs import paths quickly.                                   |
| Folders installed        | StarterDB / CustomImport are separate LoD addons; missing folders = empty or incomplete data.      |
| Data actions             | **Merge** keeps existing pins; **Override** wipes then loads. Extra pins after Merge are expected. |
| Public channel sync      | Live DISC/CONF can reintroduce pins after a clean Override.                                        |
| Filter Map / map filters | Hidden pins often look like “missing data”; Filter Map applies Viewer chips to the world map.      |
| Zone + item / `/lcdiag`  | Distinguishes wrong coords vs duplicates vs wrong zone bucket.                                     |
| Map addon                | Default `M` map often blocks pin clicks; Magnify / ElvUI / scripted map matter.                    |
| Errors                   | Lua faults vs “expected” filter/data behavior.                                                     |




## Paste into Discord

```
Copy this, fill in each line, and reply in the thread.

**LootCollector support intake**

1. Realm: (e.g. Rexxar, Vol'jin, Bronzebeard, Dawnrise, Area 52, Darkmoon)
2. Addon version: (Settings → About, or minimap tooltip build)
3. Issue summary: (1–3 sentences: what is wrong vs what you expect)
4. When it started: (after install / update / import / share / always)
5. Symptom category: (pick one)
   - empty map
   - wrong/extra pins
   - missing pins
   - Viewer filter/search
   - freeze/crash
   - sharing/import
   - other: ___
6. Folders installed:
   - LootCollector: yes/no
   - LootCollector_StarterDB: yes/no
   - LootCollector_CustomImport: yes/no
7. Data actions tried: (Merge Starter / Override Starter / /lcimport / /lcshare received / none)
8. Public channel sync: on/off (Settings)
9. Filter Map: on/off
   Active Viewer filters (if any): Type / Slot / Usable By / Looted / Favorites / search chips: ___
10. Map filters (if known): hide looted / hide bags / min rarity / show Worldforged·Mystic Scrolls·vendors: ___
11. Zone + item (pin issues): zone name; item name or itemID
    Optional: paste `/lcdiag <itemID>` output
12. Map addon: default M / Magnify / ElvUI / other: ___
13. Steps to reproduce:
    1.
    2.
    3.
14. Screenshot: (map or Viewer with filters visible, if possible)
15. Errors: (any red Lua errors from BugSack/chat — paste text, or none)
```


# LootCollector 1.0.3r-beta

## Features added

- **Two-row Discoveries filters** — Everyday toggles stay on the top row; Source, Quality, Type, Slots, Usable By, Favorites, Enchant, and related filters sit on a second row so the list is easier to scan.
- **Stats filter** — Pick common tooltip stats from a categorized menu; each pick adds or removes a search chip.
- **Filter Presets** — Save, load, and delete up to ten named filter setups from the Discoveries window.
- **Clearer sync status** — The Viewer shows a small Sync line (Quiet through Extreme, or Suspended when traffic protection pauses the channel). The minimap tooltip uses the same wording.
- **Enhanced WF Tooltip in Settings** — Turn Worldforged upgrade lines on or off under Settings → Viewer Setup (same option as the map menu and `/lcwf`).
- **Reporter addon version on discoveries** — When a find is shared, which addon version reported it is stored and shown on Alt-tooltips and `/lcdiag`.

## Performance improvements

- **Faster Discoveries Refresh** — New sync updates land in a live list cache; Refresh usually only refilters instead of rebuilding everything.
- **Less work at login** — Worldforged list warming waits until you open Discoveries, so login hitches less.
- **Smoother busy channels** — Public sync queues handle heavy traffic without the old cost of shuffling every waiting message each time one is sent or received.

## Bug fixes

- **Arrow with Filter Map** — Auto-track again follows the same filtered pins you see on the map (it no longer depended on whatever Discoveries tab was open).
- **Decay and silent cleanup** — Removed discoveries are taken out of the zone index properly, so maps and counts stay consistent.
- **Database version key** — Saved data uses one schema version field; older duplicate keys are cleaned up on load.

# LootCollector 1.0.4r-beta

## Features added

- **Zone Summary** — Continent / parent-zone discovery count badges on the world map (map filter menu → Show Zone Summary).
- **Empty Discoveries Starter DB CTA** — When your discovery store is empty (not merely filtered), Discoveries offers a one-click merge of the bundled Starter Database.
- **Welcome tips on login** — Dismissible quick-start popup for new installs; re-enable under Settings → Behavior & Sharing.
- **Shift-click chat linking** — With chat open, Shift-click a Discoveries row or map/minimap pin to insert the item link (same muscle memory as bag items). Ctrl+Left also links from Discoveries.
- **Show to… from Discoveries** — Right-click a discovery row for a map ping to another LootCollector user (same as map pins).
- **Sync status tooltip** — Hover the Discoveries Sync label for channel join/leave guidance.

## Quality of life

- **Settings cleanup** — Grouped Map & Minimap, Toasts, Discoveries Window, Behavior & Sharing, Advanced, and About; clearer labels; Mystic options hidden on CoA.
- **Map filter menu** — Cleaner Display / Hide / Show layout; retired the redundant world-map search bar (use Discoveries + Filter Map instead).
- **Map filter button** — Anchored to World Map chrome so Magnify/Mapster zoom no longer drifts the button.
- **README** — Install-first guide (three folders, common mistakes), then features, then troubleshooting.

## Bug fixes

- **/lcarrow toggle** — Turning the navigation arrow back on no longer fails after TomTom waypoint churn; invalid waypoints are reapplied instead of silently disabling.
- **Cross-zone arrow resume** — `/lcarrow` remembers the last tracked discovery and resumes it even when you are in another zone.
- **ESC + Discoveries** — ESC closes Discoveries when the map is closed (keep-open-with-map no longer blocks ESC incorrectly).
- **Discoveries strata** — Viewer sits above low UI / minimap chrome so it stays clickable.

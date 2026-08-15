# LootCollector 1.0.5 (No more beta!)

## Features added

- **Public channel on for new users** — Public sync and Auto-Pause Shield default on (5000 msgs/min). Existing profiles keep their on/off choice. A one-time Enable/Not now prompt appears if sync was off. This will ensure better pin accuracy overall.
- **Decay and Fade** — Discoveries fade after 30 days without a sighting, go stale at 90, and are removed at 120. Report as Gone uses community votes (5 / 6 / 7). Discoveries has Fade: All / Hide / Only. Filter Map applies Fade to map, minimap, and Arrow.
- **LC icon** — Custom LC art on the world-map filter button and the minimap button.
- **Arrow Skip / Clear** — Skip and Clear buttons under the TomTom arrow. Skip works for auto-track and Navigate here (this session only). `/lcarrow clearskip` still clears the list.

## Bug fixes

- **Auto-track resume** — Auto-track Nearest Unlooted starts again after `/reload` and login.

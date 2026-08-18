# LootCollector 1.0.6

## Bug fixes

- **Leftover map stamps** — Worldforged pins copied onto wrong maps (same item, same map fractions) merge onto the real pin on login. Looted marks move with the pin that stays.
- **Verified coordinates** — Verified a lot of coordinates by hand. Extra-zone copies collapse onto those pins; looted marks move with them.
- **Wrong-zone copies** — Fake stamps are removed for items that only spawn in one place (for example Kixxle’s potion in Wetlands, Morin’s Jug in Loch Modan, Bonechopper in Stranglethorn). Those pins are deleted, not merged onto a different item.
- **Not in the game** — Supply Runner’s Pants, Scholar’s Ring of Enlightenment, and The Vanishing Strap are untracked. Existing pins are removed and will not come back from loot, channel, or Starter DB.
- **Worldforged upgrade tooltips** — Dung–T3 upgrade lines show again on Worldforged items when Enhanced WF Tooltip is on.
- **TomTom Arrow** - Arrow clears on item loot correctly. No longer disappears randomly.
- **Map filter button** — LootCollector sits in the world map title bar now, makes it easier to find as it was floating around. Will play nice with map addon buttons like Mapster.

Looted marks on real pins are kept. You do not need to reset any data.
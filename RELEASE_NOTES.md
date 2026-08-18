# LootCollector 1.0.6

## Pin cleanup

- **Leftover map stamps** — Worldforged pins copied onto wrong maps (same item, same map fractions) merge onto the real pin on login. Looted marks move with the pin that stays.
- **Verified coordinates** — A number of spawns were checked by hand (including Prancefin Ring in Un’Goro). Extra-zone copies collapse onto those pins; looted marks move with them.
- **Wrong-zone copies** — Fake stamps are removed for items that only spawn in one place (for example Kixxle’s potion in Wetlands, Morin’s Jug in Loch Modan, Bonechopper in Stranglethorn). Those pins are deleted, not merged onto a different item.
- **Not in the game** — Supply Runner’s Pants, Scholar’s Ring of Enlightenment, The Vanishing Strap, and Goldshire Traveler’s Boots are untracked. Existing pins are removed and will not come back from loot, channel, or Starter DB.

## Navigation and map

- **TomTom Arrow** — Stays on the pin until you loot (or Skip / Hide). It no longer vanishes or freezes while you travel. If bags were full and you loot after freeing a slot, the arrow still clears.
- **Map filter button** — **LootCollector** sits in the world map title bar (left of shrink/expand, and left of Mapster if that button is there). It cannot be dragged. The minimap button still uses the LC icon.
- **Worldforged upgrade tooltips** — Dung–T3 upgrade lines show again on Worldforged items when Enhanced WF Tooltip is on.

Looted marks on real pins are kept. You do not need to reset any data.

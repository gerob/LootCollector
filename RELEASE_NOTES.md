# LootCollector 1.0.6

## Bug fixes

- **Leftover map stamps** — Worldforged pins copied onto leftover/wrong maps (same item, same map fractions) merge onto the real pin on login. Looted marks move with the pin that stays.
- **Verified coordinates** — Plains Bolter is locked to Arathi Highlands. Several Tirisfal leftover AreaID copies are locked to Tirisfal Glades. Extra-zone copies collapse onto those pins; looted marks move with them.
- **Wrong-zone copies** — Fake stamps are removed for items that only spawn in one place (for example Kixxle’s potion in Wetlands, Morin’s Jug in Loch Modan, Bonechopper in Stranglethorn). Those pins are deleted, not merged onto a different item.
- **Not in the game** — Supply Runner’s Pants and Scholar’s Ring of Enlightenment are untracked. Existing pins are removed and will not come back from loot, channel, or Starter DB.
- **Worldforged upgrade tooltips** — Dung–T3 upgrade lines show again on Worldforged items when Enhanced WF Tooltip is on.

Looted marks on real pins are kept. You do not need to reset data.

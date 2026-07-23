# LootCollector for Project Ascension

**LootCollector** is a collaborative hunting and navigation tool for Worldforged gear, chest spawns, special vendors, and Mystic Scrolls on Project Ascension. The addon pools discovery data from the community so you can filter for the upgrades your character needs and navigate straight to them.

![Map overview with LootCollector pins](docs/images/map-icons.png)

> [!IMPORTANT]
> **Compatibility:** Built for Project Ascension realms including **WR** (Bronzebeard), **CoA** (Rexxar / Vol’jin), **Freepick** (Dawnrise / Area 52), and **Wildcard** (Darkmoon). The sharing model works best for **static world spawns** (chests, nodes, vendors). On setups where drops are mostly random from mobs, coordinate sharing is less useful.

> [!TIP]
> **Support development:** If LootCollector helps your progression, consider [GitHub Sponsors](https://github.com/sponsors/gerob). In-game: **Settings → About** has Discord and a **Download (GitHub)** copy link.

---



## Installation

1. Download the latest release from [Releases](https://github.com/gerob/LootCollector/releases).
2. Extract the ZIP.
3. Copy these three folders into `Interface\AddOns` (keep the folder names exactly as they are):
  - `LootCollector`
  - `LootCollector_StarterDB`
  - `LootCollector_CustomImport`
4. Restart World of Warcraft.

The Starter DB and Custom Import addons load on demand with LootCollector. If you only copy `LootCollector`, the Viewer still works, but you will not get the bundled community starter database or the custom-import helpers.

![Settings About tab with Download link](docs/images/settings-about.png)

---



## How LootCollector Speeds Up Progression



### 1. Target the Exact Upgrades for Your Build

- **Filter by class and archetype:** On CoA, filters highlight gear usable by your custom archetype (e.g. *Templar*, *Venomancer*) and hide incompatible relics where appropriate.
- **Search + chips:** In the Discoveries Viewer (`/lcv`), search by **name**, **zone**, or **tooltip text** (stats, effects, spells), then **Add** chips. Chips support AND/OR within a row.
- **Type, slot, and more:** Narrow by **Type** (Armor / Weapon / Misc), equip slot, quality, Favorites, Looted, **Enchant** (Mystic Enchants; hidden on CoA), Undiscovered Worldforged, and date filters.
- **Filter Map:** Opt-in toggle applies your active Discoveries filters (including chips) to world map, minimap, and Arrow pins.

![Discoveries Viewer with search chips and filters](docs/images/viewer-search-filters.png)

### 2. Streamline Your Farming Routes

- **Auto-track closest upgrades:** With **TomTom**, the navigation arrow points to the nearest unlooted discovery that matches your filters (or a pin you set manually).
- **Skip and recalculate:** Skip awkward or dangerous nodes from the map menu; the arrow picks the next target.
- **Cut map clutter:** Hide looted items, bags, low quality, and use **Filter Map** so only what you care about stays on the map.

![Filtered map pins and navigation arrow](docs/images/map-filter-arrow.png)

### 3. Coordinate with Community and Allies

- **Automatic sharing:** Qualifying discoveries can sync with other LootCollector users on the public channel (when sharing is enabled).
- **Real-time updates:** Toasts and map updates as others find items.
- **“Show to…”:** Right-click a pin → **Show to…** to ping a friend; if they accept, it pulses on their map.

![Show to menu](docs/images/showto.png)

### 4. Vendors, Accuracy, and Realm Data

- **Special vendors:** Detect and list vendors such as Blackmarket / Exquisite / Ring Vendor styles; inventory shows on the Vendors tab and can appear as map pins.
- **Report as Gone:** Right-click a pin to vote a spawn empty; enough agreement fades/removes stale nodes.
- **Realm isolation:** Data stays in realm buckets so Seasonal, Wildcard, WR, and CoA data do not mix.

![Vendors tab in the Viewer](docs/images/vendors-tab.png)

---



## Essential Shortcuts

- **Shift + Left Click** (on a discovery): Pan the world map to that location with a pulse highlight.
- **Ctrl + Alt + Left Click:** Link the item and coordinates into your active chat (party, guild, or whisper).
- **Alt + Mouseover:** Extra discovery details in the tooltip.
- **Ctrl + Mouseover:** Soften crowded pin tooltips so you can pick one target.
- **Shift + Left Click** (minimap button): Drag to reposition the button.

---



## Slash Commands

- `/lc` – Settings (filters, visibility, About / Download).
- `/lcv` – Discoveries Viewer.
- `/lcarrow` – Toggle navigation arrow.
- `/lcarrow clearskip` – Clear skipped targets.
- `/lctoggle` – Show/hide map and minimap pins.
- `/lcshare <party|raid|guild|whisper> [player]` – Broadcast your discovery **database** to others (not the GitHub download link).
- `/lcexport` / `/lcimport` – Manual text export/import (e.g. Discord).
- `/lcpause` – Hibernate background work (channel, tickers); run again to resume.
- `/lcdiag <itemID|link>` – Dump local discoveries for one item (zones, coords, merge counts).

---



## FAQ



#### I just installed or updated and my map is empty. What should I do?

Databases are per realm. Import a community string with `/lcimport`, sync with friends/guild via `/lcshare`, or play until discoveries (and public sync, if enabled) fill the map. A starter database may merge on login for new installs.

#### How do I send one specific location to a friend?

Right-click the pin → **Show to…** → their character name. They get a prompt to show it on their map.

#### Why did a pin fade or disappear?

Other players reported it gone. Enough votes remove outdated entries so you waste fewer trips.

#### How do I share my full database?

`/lcshare party` (or raid/guild/whisper), or `/lcexport` for a pasteable string. Recipients use `/lcimport`. For the **addon download URL**, use Settings → About → **Download (GitHub)** (copy popup).

#### Shared vs per-character Favorites?

By default Favorites are **shared** across characters on the account profile. Settings → Viewer Setup → **Per-character Favorites** is opt-in; turning it on copies the shared list into an empty character list the first time.

#### Why do some discoveries show on the continent map?

Some 3.3.5a sub-zones lack their own map textures, so the client uses the continent. LootCollector stores coordinates as the game reports them.

**Known examples:** Dire Maul, Caverns of Time entrance, Blackrock Mountain, Deadmines entrance, Wailing Caverns entrance, Scarlet Monastery entrance.

#### Why are some item names or icons missing?

The client has not cached that item yet (“Unknown Item” / ?). The addon retries lookups in the background.

#### Enhanced Worldforged tooltips do nothing?

Install **AtlasLoot** with **AtlasLoot_Cache** enabled.

#### I can’t click map pins or open the right-click menu?

The default **M** map can block pin interaction. Use `/script WorldMapFrame:Show()` (macro it), or a map addon such as **Magnify (WotLK Edition)** or **ElvUI**.

---



## Contributing

Bug fixes and features are welcome. See **[CONTRIBUTING.md](LootCollector/CONTRIBUTING.md)** for guidelines.

#### Credits

- **Author:** Skulltrail
- **Contributors:** Deidre, Rhenyra, Morty, Markosz, Bandit Tech, xan, Stilnight, Xurkon, Jollygg, and community helpers
- **Early alpha top collectors:** Morty, Laya, Brokenheart, Mie, Rhen, Aaltrix, Insanestar, Harrydn, Blutact



#### Sponsors

- @ERitzman (first sponsor — thank you!)



#### License

[MIT License](LootCollector/LICENSE.MD)
# LootCollector for Project Ascension

**LootCollector** is a collaborative hunting and navigation tool for Worldforged gear, chest spawns, special vendors, and Mystic Scrolls on Project Ascension. It pools discovery data from the community so you can filter for the upgrades your character needs and navigate straight to them.

Map overview with LootCollector pins

> [!IMPORTANT]
> **Compatibility:** Built for Project Ascension realms including **WR** (Bronzebeard), **CoA** (Rexxar / Vol’jin), **Freepick** (Dawnrise / Area 52), and **Wildcard** (Darkmoon). Sharing works best for **static world spawns** (chests, nodes, vendors). On setups where drops are mostly random from mobs, coordinate sharing is less useful.

> [!TIP]
> **Support development:** If LootCollector helps your progression, consider [GitHub Sponsors](https://github.com/sponsors/gerob). In-game: **Settings → About** has Discord and a **Download (GitHub)** copy link.

---



## Installation



### 1. Download

Get the latest release ZIP from [Releases](https://github.com/gerob/LootCollector/releases). Prefer a **Release** asset over cloning the raw repository unless you know you need a development build.

### 2. Extract and place folders

Extract the ZIP. You should see **three** addon folders. Copy all three into your Ascension `Interface\AddOns` directory, keeping the folder names exactly as they are:


| Folder                       | Required?             | Purpose                            |
| ---------------------------- | --------------------- | ---------------------------------- |
| `LootCollector`              | Yes                   | Core addon                         |
| `LootCollector_StarterDB`    | Strongly recommended  | Bundled community starter database |
| `LootCollector_CustomImport` | Optional but included | Helpers for custom import packs    |


Typical path (common install):

`...\Ascension\resources\ascension-live\Interface\AddOns`

**Correct layout:**

```text
Interface\AddOns\
  LootCollector\
  LootCollector_StarterDB\
  LootCollector_CustomImport\
```

**Common mistakes:**

- Nesting an extra folder (e.g. `AddOns\LootCollector-1.0.x\LootCollector\…`) — Ascension will not load it.
- Renaming folders or only copying the outer ZIP folder.
- Leaving an older `LootCollector` folder next to a new one with a different name.



### 3. Restart the client

Fully quit and restart Ascension (a UI reload alone is not enough for a first install).

### 4. Confirm it loaded

1. At the character select screen (or in-game), open the addon list and ensure **LootCollector** is enabled.
2. Log in and run `/lc` — Settings should open.
3. Run `/lcv` — the Discoveries window should open.

If `/lc` does nothing, the addon did not load. Recheck folder names and that you are editing the Ascension client’s `Interface\AddOns` (not a retail or classic install).

Settings About tab with Download link

---



## First steps after install

1. **Open Discoveries:** `/lcv`. If the list is empty, use the on-screen prompt to merge the **Starter DB** (when `LootCollector_StarterDB` is installed), or import a string with `/lcimport`.
2. **Open Settings:** `/lc` — turn on sharing / public sync if you want community updates (**Behavior & Sharing**).
3. **Open the world map** — discovery pins appear when your database has entries for the current zone. Use the **LootCollector** map filter button for quick hide/show options, or enable **Filter Map** in Discoveries to apply Viewer filters to pins.
4. **Optional:** Install **TomTom** for the navigation arrow (`/lcarrow`).

Databases are **per realm**. An empty map on a new realm or character is normal until you merge Starter DB, import/share data, or collect discoveries in the world.

---



## Features



### Target the upgrades for your build

- **Filter by class and archetype:** On CoA, filters highlight gear usable by your custom archetype (e.g. *Templar*, *Venomancer*) and hide incompatible relics where appropriate.
- **Search + chips:** In Discoveries (`/lcv`), search by **name**, **zone**, **tooltip text** (stats, effects, spells), **Type**, or **Slot**, then **Add** chips. Chips support AND/OR within a row.
- **Type, slot, and more:** Narrow by **Type** (Armor including Shields / Weapon / Misc), equip slot, quality, Favorites, Looted, **Enchant** (Mystic Enchants; hidden on CoA), and date filters.
- **Filter Map:** Opt-in toggle applies your active Discoveries filters (including chips) to world map, minimap, and Arrow pins.

Discoveries Viewer with search chips and filters

### Streamline farming routes

- **Auto-track closest upgrades:** With **TomTom**, the navigation arrow points to the nearest unlooted discovery that matches your filters (or a pin you set manually).
- **Skip and recalculate:** Skip awkward or dangerous nodes from the map menu; the arrow picks the next target.
- **Cut map clutter:** Hide looted items, bags, low quality, and use **Filter Map** so only what you care about stays on the map.

Filtered map pins and navigation arrow

### Coordinate with community and allies

- **Automatic sharing:** Qualifying discoveries can sync with other LootCollector users on the public channel (when sharing is enabled).
- **Real-time updates:** Toasts and map updates as others find items.
- **“Show to…” (map ping):** Right-click a pin or Discoveries row → **Show to… (map ping)** to whisper another LootCollector user; if they accept, it pulses on their map.
- **Shift-click into chat:** With chat open (cursor blinking), Shift-click a Discoveries row or map/minimap pin to insert the item link — same muscle memory as linking bag items.

Show to menu

### Vendors, accuracy, and realm data

- **Special vendors:** Detect and list vendors such as Blackmarket / Exquisite / Ring Vendor styles; inventory shows on the Vendors tab and can appear as map pins.
- **Report as Gone:** Right-click a pin to vote a spawn empty; enough agreement fades/removes stale nodes.
- **Realm isolation:** Data stays in realm buckets so Seasonal, Wildcard, WR, and CoA data do not mix.

Vendors tab in the Viewer

---



## Essential shortcuts

- **Shift + Left Click** (chat open): Insert the item link into chat (Discoveries row or map/minimap pin).
- **Shift + Left Click** (chat closed, on a discovery): Pan the world map to that location with a pulse highlight.
- **Ctrl + Left Click** (on a discovery): Insert the item link into chat (opens chat if needed).
- **Ctrl + Right Click** (on a discovery): Insert item + zone + coordinates into chat.
- **Ctrl + Alt + Right Click** (on a map pin): Insert item + zone + coordinates into chat.
- **Alt + Mouseover:** Extra discovery details in the tooltip.
- **Ctrl + Mouseover:** Soften crowded pin tooltips so you can pick one target.
- **Shift + Left Click** (minimap button): Drag to reposition the button.

---



## Slash commands

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



## Troubleshooting



### Addon does not load (`/lc` does nothing)

- Confirm all folders sit directly under `Interface\AddOns` with the exact names above (no extra nesting).
- Confirm you installed into the **Ascension** client path, then fully restarted the game.
- Check the addon list: LootCollector must be enabled for that character.



### Map or Discoveries list is empty after install/update

- Databases are **per realm**. Import a community string with `/lcimport`, sync via `/lcshare`, merge **Starter DB** from the Discoveries empty-state prompt, or play until discoveries (and public sync, if enabled) fill data.
- In Discoveries, clear filters / turn off **Filter Map** if filters are hiding everything.
- Check the map filter button: **Hide All Discoveries** or hibernation (`/lcpause`) will clear pins.



### I can’t click map pins or open the right-click menu

The default **M** map can block pin interaction. Use `/script WorldMapFrame:Show()` (macro it), or a map addon such as **Magnify (WotLK Edition)** or **ElvUI**.

### How do I send one specific location to a friend?

Right-click the pin or a Discoveries row → **Show to… (map ping)** → their character name. They get a prompt to show it on their map. (This is not the same as pasting an item link into chat.)

### How do I share my full database?

`/lcshare party` (or raid/guild/whisper), or `/lcexport` for a pasteable string. Recipients use `/lcimport`. For the **addon download URL**, use Settings → About → **Download (GitHub)** (copy popup).

### Why did a pin fade or disappear?

Other players reported it gone. Enough votes remove outdated entries so you waste fewer trips.

### Shared vs per-character Favorites?

By default Favorites are **shared** across characters on the account profile. Settings → **Discoveries Window** → **Per-character Favorites** is opt-in; turning it on copies the shared list into an empty character list the first time.

### Why do some discoveries show on the continent map?

Some 3.3.5a sub-zones lack their own map textures, so the client uses the continent. LootCollector stores coordinates as the game reports them.

**Known examples:** Dire Maul, Caverns of Time entrance, Blackrock Mountain, Deadmines entrance, Wailing Caverns entrance, Scarlet Monastery entrance.

### Why are some item names or icons missing?

The client has not cached that item yet (“Unknown Item” / ?). The addon retries lookups in the background.

### Enhanced Worldforged tooltips do nothing?

Install **AtlasLoot** with **AtlasLoot_Cache** enabled.

---



## Contributing

Bug fixes and features are welcome. See **[CONTRIBUTING.md](LootCollector/CONTRIBUTING.md)** for guidelines.

### Credits

- **Author:** Skulltrail
- **Contributors:** Deidre, Rhenyra, Morty, Markosz, Bandit Tech, xan, Stilnight, Xurkon, Jollygg, and community helpers
- **Early alpha top collectors:** Morty, Laya, Brokenheart, Mie, Rhen, Aaltrix, Insanestar, Harrydn, Blutact



### Sponsors

- @ERitzman (first sponsor — thank you!)



### License

[MIT License](LootCollector/LICENSE.MD)
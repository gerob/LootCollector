# Regression checklist

Living maintainer list. Run between leftover `/lcdiag` dumps. Hot path ~5 min. Smoke ~10 min.

Mark each check Pass / Fail / Skip.

If a pin is missing, use `/lcrestorestarter <id>` or Merge Starter. Do not Override Starter.

Refresh canary IDs when updating RELEASE_Notes.

## A. Canaries (after every `/reload` that touched CA / leftover)

1. `/lcdiag 415038` — Plains Bolter: **one** pin, Arathi 17, xy `0.4011, 0.3038` (CA).
2. `/lcdiag 450983` — Apprentice Staff: **multiple** starter pins still present (1244, 1240, and the rest). Not collapsed.
3. `/lcdiag 515323` — Bottled Oozeling: still tracked; do not untrack.
4. Map open in Arathi: Bolter pin on the Arathi map, not Dun Morogh.
5. No Lua error on login; leftover-collapse chat only for true leftover-xy, not starter-family wipes.

## B. Login / authority (hot)

1. `/reload` with map closed, then open map: pins appear, no endless flicker.
2. CoordAuthority other-zone: leftover zone for a locked item is gone; looted flag remapped onto the keep pin.
3. Leftover-xy (same item, `|dx|<0.02` and `|dy|<0.02`, different zones): one pin, outdoor/StarterDB keep rank unchanged.
4. Different-xy same item (staff-style): still N pins.
5. XY snap: only after a **published** revision bump. Until RELEASE_Notes, new CA rows may collapse zones without snapping keep xy.

## C. Ingest / loot (hot)

1. WF spawn pickup (BoP Okay): creates or `+mc` on the zone pin; does not invent a second pin in another leftover zone.
2. WF bag echo / later mob loot: **MarkLooted** only; no create, no xy move, no mc. Class/weapon usability does not block MarkLooted.
3. Public DISC for a CA item in a forbidden zone: rejected or merged onto the authority pin, not a new pin.
4. `/lcshare` / `/lcimport` of a leftover-zone copy: same merge, not a second pin.
5. Rexxar and Vol'jin are mirrored: same WF item, same zone, same xy on both. Looted does not cross realms (same character name on each keeps its own looted marks).

## D. Map / Viewer smoke (~10 min)

1. Filter Map On: world + minimap match Discoveries filters; Off restores.
2. Search chip add/remove; Fade All / Hide / Only; hide looted.
3. `/lcpause` / unpause; auto-track nearest unlooted resumes after `/reload`.
4. Arrow Skip / Clear; `/lcarrow` still points at a pin.
5. Discoveries version hover; CoA hides Enchant filter; vendors tab opens; `/lcvendor` runs.

Skip unless you touched that code: decay Gone votes, `/lcdecay`, `/lcwf` tooltip, MS pins, CustomImport.

## When updating RELEASE_Notes

1. Bump `CoordAuthorityRevision` once for the unpublished CA batch.
2. Add/adjust canary rows in this file (new locked IDs).
3. Publish.

# Calamity Terraria Server — Design

**Date:** 2026-09-28
**Status:** Approved by user
**Host:** `jw` @ 192.0.2.197

## Goal

An always-on modded Terraria dedicated server running Calamity plus a curated mod set, reachable
over the internet by a small friend group, surviving host reboots unattended, and recoverable if
the world is corrupted or a mod update breaks the save.

## Existing infrastructure (verified 2026-09-28)

| Fact | Value |
|---|---|
| Host | `jw` @ 192.0.2.197, Windows 11, always on |
| CPU / RAM | Ryzen 5 5600G (6c/12t) / 32 GB, 23.5 GB free |
| Disk | `C:` 360 GB free, `D:` 454 GB free (only 22 GB used) |
| Already hosting | Modded Minecraft (ATM10/NeoForge, java ~0.73 GB idle), AI Art Factory dashboard on `:8077` |
| SSH | native `ssh user@192.0.2.197`, key `C:\Users\jamil\.ssh\id_ed25519`, remote shell is `cmd.exe`. **NOT** `wsl ssh` — that presents the wrong key |
| Port 7777 | Free |
| Tailscale | Installed at `C:\Program Files\Tailscale` but unauthenticated (`state: NoState`). Unused by this project |
| Mod source | Workstation 192.0.2.99, 41 tModLoader workshop mods at `C:\Program Files (x86)\Steam\steamapps\workshop\content\1281930` |

Terraria's server is single-threaded, so it will use roughly one of twelve threads and 2-4 GB.
No meaningful contention with the Minecraft server.

## Decisions

### Server runtime

**Standalone tModLoader dedicated server** from GitHub releases — not the Steam build.
Rationale: needs no Steam license and no running Steam client, which matters on an unattended host.

Layout:

```
D:\terraria-server\            server binaries
D:\terraria-server\data\       -tmlsavedirectory target: world, configs, Mods
D:\terraria-server\backups\    rotating world backups
```

The `-tmlsavedirectory` override keeps world and mods on the roomy `D:` drive rather than buried
under `Documents`.

### Mod list — 31 total

**Core (3)**

| Mod | Workshop ID |
|---|---|
| CalamityMod | 2824688072 |
| CalamityModMusic | 2824688266 |
| ClamExtraMusic | 2835214226 |

**Calamity addons (3) — not yet in the workshop folder, must be downloaded**

| Mod | Note |
|---|---|
| Wrath of the Gods | Nameless Deity, Avatar of Emptiness, Solyn NPC. Needs `Luminance` (already present) |
| Catalyst Mod | Astrageldon superboss, extra Astral content |
| Calamity: Vanities | Cosmetic only |

**Quality of life (16)**

| Mod | Workshop ID |
|---|---|
| MagicStorage | 2563309347 |
| RecipeBrowser | 2619954303 |
| BossChecklist | 2669644269 |
| Fargowiltas (Mutant Mod) | 2570931073 |
| WMITF | 2563851005 |
| DialogueTweak | 2563815443 |
| HPAware | 2564503881 |
| CompareItemStats | 2576847291 |
| HelpfulHotkeys | 2645058109 |
| DPSExtreme | 2827999994 |
| SharedMap | 2815010161 |
| SummonersAssociation | 2561619075 |
| ProjectilesBeGone | 3098311063 |
| CoolerItemVisualEffect | 2829306780 |
| ShorterRespawn | 2562997415 |
| PylonShield | 2820025575 |

**Comfort — user's explicit picks (4)**

| Mod | Workshop ID | Shortcuts |
|---|---|---|
| OreExcavator | 2565639705 | Vein mining |
| MaxStackExtra | 2562915378 | Stack limits |
| AutoReroll | 2707400823 | Reforge clicking |
| AdvancedAmmunition | 2567903865 | Ammo handling |

**Libraries (5) — dependency-driven**

SerousCommonLib (2908170107), Luminance (3222493606), LogSpiralLibrary (3019394991),
SubworldLibrary (2785100219), PropertyPanelLibrary (3625429529).

These are present because other mods depend on them. The authoritative check is tModLoader itself,
which reports missing dependencies on load. Resolve the exact set at implementation time rather
than assuming this list is complete or minimal.

### Excluded, with reasons

**Cut for power creep** — user asked to filter "super strong or egregious" mods:

- **Antisocial** (2564872136) — makes vanity slots grant real accessory effects, roughly five free
  accessory slots. Largest balance breaker in the folder.
- **WingSlotExtra** (2597324266) — dedicated wing slot, one more accessory than intended.
- **AlchemistNPCLite** (2599842771) and its Chinese duplicate **AlchemistNPCLiteCn** (2962495092) —
  NPC sells buff potions and utility items outright, removing the potion-farming loop Calamity's
  difficulty is tuned around.
- **JourneyTrend** (2965168591) — Journey-mode-flavored power, inappropriate on a shared server.
- **ImproveGame** (2797518634) — bundles genuine QoL with creative-mode tooling (building wands,
  infinite item sources). Config-tameable, but too large a surface to police across a group.
  Its dependency **SilkyUIFramework** (3403460014) is dropped with it.

**Cut for conflict rather than power:**

- **TerrariaOverhaul** (2811803870) — rewrites movement, combat feel, dodge rolls, fire spread.
  Calamity's balance assumes vanilla combat, and Overhaul is a known source of multiplayer jank
  alongside large content mods.
- **CalRemix** (2956324268) — **its own mod description states it is not built for multiplayer.**
  Decisive for a friends server regardless of content quality. Reception is also mixed: recurring
  complaints that polish doesn't match base Calamity, and its signature Fanny the Flame helper is
  divisive.
- **ThoriumMod** (2909886416) — user chose Calamity-only scope. Viable for a future second world.
- **ThoriamityConvergenceREDUX** (3106201538) — only functional with Thorium present.
- **BossDPS** (2987060992) — redundant with DPSExtreme, which is the multiplayer-aware meter.

### World

| Setting | Value |
|---|---|
| Size | Large |
| Difficulty | Expert — what Calamity is balanced around |
| Evil biome | Crimson (early armor regen modestly helps a group) |
| Revengeance | Off at creation; in-game toggle once the group finds its footing |
| Player cap | 8 |
| Password | Required |
| Journey mode | No |

Worldgen-affecting choices (size, evil biome) are irreversible after creation. Thorium and CalRemix
were both rejected partly on this timing constraint.

### Networking

Port forwarding, chosen over Tailscale so friends need no client software.

- Server binds TCP 7777, password set
- Windows Firewall inbound allow rule for TCP 7777 — **agent does this**
- Router: forward TCP 7777 to 192.0.2.197 — **user does this**, agent has no router access
- Check whether the public IP is static. If dynamic, friends break silently the day it rotates;
  DuckDNS or similar becomes a follow-up

The password is not optional. An exposed 7777 gets scanned.

### Operations

- **Autostart** — scheduled task on boot, mirroring the existing `AIArtFactoryDashboard` pattern
  on this host
- **Rotating world backups** on a schedule, separate from Terraria's own autosave. A corrupted or
  mod-broken modded world ends the playthrough outright, and 31 mods is substantial surface area
- **Pinned mod versions.** No auto-update mid-playthrough — a Calamity update landing between
  sessions can break a save. Snapshot the `Mods` folder to enable rollback

### Client onboarding

Friends install Terraria plus tModLoader (free), then connect to the public IP on 7777.
tModLoader offers to auto-download the server's mod set on join, so nobody assembles the list by
hand. Verify this behaviour during implementation rather than promising it to the group first.

## Risks

| Risk | Mitigation |
|---|---|
| Mod update breaks the save | Pinned versions, `Mods` folder snapshot, rotating world backups |
| World corruption ends the playthrough | Rotating backups on a schedule |
| Base Calamity multiplayer jank — boss desync, some items misbehaving | Accepted. Known limitation, not a server fault. Tell the group up front |
| Exposed port 7777 scanned from the internet | Server password, firewall rule scoped to the single port |
| Dynamic public IP rotates | Detect at setup; DDNS follow-up if needed |
| tModLoader version vs mod version mismatch | Verify compatibility at implementation; install matching stable versions |

## Out of scope

Tailscale, Thorium, CalRemix, Infernum Mode, DDNS unless the IP proves dynamic, any interaction
with the Minecraft server on the same host.

## Open items

- **Crimson vs Corruption** — decided Crimson, reversible only before world creation.
- **Exact tModLoader release and mod-version compatibility** — verified at implementation, not
  assumed here.
- **Addon acquisition path** — default is the user subscribing to the three addons on Steam
  Workshop and the agent copying the `.tmod` files. `steamcmd` is the fallback if the user prefers
  not to use the Steam client.

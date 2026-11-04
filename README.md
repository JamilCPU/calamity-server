# Calamity Server

Operations tooling for an always-on, modded Terraria dedicated server (tModLoader with the Calamity mod and a curated set of roughly 30 mods) for a small friend group. It is a set of PowerShell scripts that install the standalone server, keep it alive across reboots, take rotating world backups, snapshot the mod set for rollback, and let you send console commands to the running server. The design document in `docs/` records the decisions and the reasoning behind them.

## Stack

- tModLoader standalone dedicated server (downloaded from the official GitHub releases; not the Steam build)
- PowerShell 5.1 on Windows 11, Windows Task Scheduler for autostart and backups
- Python 3 (one helper that reads a world file header)

## Running

Paths in the scripts assume the server lives in `D:\terraria-server`; edit the `$Root` variable at the top of each script to change that. Run from an elevated PowerShell on the host.

```powershell
# 1. Install the pinned tModLoader release and create the data/backup folders
.\scripts\install-server.ps1
.\scripts\prepare-dotnet.ps1        # pre-delivers the .NET runtime the launcher expects

# 2. Create the server config from the template and set a real password
Copy-Item server\serverconfig.template.txt D:\terraria-server\serverconfig.txt
# edit serverconfig.txt: replace password=CHANGEME

# 3. Start the server (detached, under the supervisor) and check it
.\scripts\run-server.ps1
.\scripts\status.ps1

# 4. Register boot-autostart and hourly-backup scheduled tasks
.\scripts\register-tasks.ps1
```

Day-to-day:

```powershell
.\scripts\send-command.ps1 save                       # console command channel
.\scripts\send-command.ps1 'say Restarting in 60s'
.\scripts\send-command.ps1 exit                       # graceful shutdown, saves first
.\scripts\backup-world.ps1                            # manual world backup (keeps newest 48)
.\scripts\snapshot-mods.ps1                           # zip Mods + enabled.json before changing mods
.\scripts\activity-report.ps1                         # uptime, logins, chat, scanner noise
python scripts\read-world-evil.py <world.wld>         # report Crimson vs Corruption
```

## Project layout

- `scripts/` - install, run/supervise, status, backup, snapshot, command channel, reporting
- `server/serverconfig.template.txt` - config template (the real `serverconfig.txt` is git-ignored because it holds the password)
- `server/enabled.json` - list of enabled mods
- `docs/superpowers/specs/` - design document: goals, mod choices and exclusions, networking, operations, risks

## Notable details

- A supervisor script holds the server's stdin open; without it a detached server reads EOF and exits partway through mod loading.
- The server runs on a non-default port to avoid constant bot scans, with the vanilla anti-cheat disabled because it falsely kicks players on a heavily modded server.
- Backups copy both `.wld` and `.twld` files together; restoring without the `.twld` loses modded state. Backups and live world data are not committed.

## Status

Working personal deployment. Mod files themselves are not included (they come from Steam Workshop), and the design document reflects the original plan, so details such as the port differ from the current scripts.

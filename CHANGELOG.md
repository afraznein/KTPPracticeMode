# KTP Practice Mode - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.4.2] - 2026-04-25

### Added
- **Adopted `ktp_version_reporter` shared include** — plugin now registers with the fleet-wide `amx_ktp_versions` rcon command (ADMIN_RCON). Output reports name, version, build SHA, and build time alongside other KTP plugins. See KTPMatchHandler 0.10.116 for the canary release introducing the include.
- **`compile.sh` build-info generation** — git short SHA + UTC build time written to `build_info.inc` and baked into the .amxx so the rcon command can report what's actually deployed.

---

## [1.4.1] - 2026-04-20

### Added
- **Diagnostic logging in grenade paths** — `dod_grenade_explosion` now logs entry state (player id, wpnid, practice/connected/alive flags) and the return values of `dodx_give_grenade()`, `dodx_set_grenade_ammo()`, `dodx_send_ammox()`. `cmd_grenade` gets the same diagnostics for parity.
- Low-volume (only fires during active practice mode) and kept permanent. Purpose is to narrow the 2026-04-17 ATL2 regression where auto-refill silently stopped working after a map change.

---

## [1.4.0] - 2026-04-04

### Fixed
- **`.grenade` not spawning grenades** — DoD removes the weapon entity when the last grenade is thrown. Setting pdata ammo alone creates "invisible" grenades the player can't select. Now always calls `dodx_give_grenade()` to recreate the weapon slot, then `dodx_set_grenade_ammo()` + `dodx_send_ammox()` to set ammo and sync HUD.
- **Infinite grenade refill on explosion** — Same root cause. `dod_grenade_explosion` handler now gives weapon entity + sets ammo + syncs HUD on every explosion.
- **`.noclip` not working** — DODX `CPlayer` array was uninitialized in extension mode on first map load because `g_pFirstEdict` was NULL (SV_ActivateServer hook registered after server already activated). Fixed in KTPAMXX 2.7.4 DODX module with fallback init.

### Changed
- Requires KTPAMXX 2.7.4+ (DODX fallback init for first map load)

---

## [1.3.2] - 2026-03-24

### Fixed
- **`client_death` now clears noclip engine state** — Previously only cleared the tracking flag but did not call `dodx_set_user_noclip(0)`. Players who died in noclip respawned still flying, and `exit_practice_mode` skipped them because the flag was already false.
- **Hostname restore race on map change** — The 0.5s restore task fired before server configs loaded, potentially restoring an empty or stale hostname. Now fires at 1.5s and reads the hostname fresh from the cvar after configs have run.
- **British team support in `.grenade`** — Team 3 (British) was unhandled, getting "must be on a team" error. Now gives Mills Bomb (DODW_MILLS_BOMB) for British players.
- **Repeating task accumulation guard** — Added `remove_task` before each `set_task("b")` call in `cmd_practice` to prevent duplicate tasks on edge-case double-activation.
- **`g_szBaseHostname` buffer increased from 64 to 128** — Prevents silent truncation of long hostnames, matches the downstream `hostname[128]` buffer.

### Changed
- **Version display removed** — No longer sends plugin info to players on connect. Dead `TASK_VERSION_BASE`, `task_version_display`, `client_putinserver` version logic all removed.
- **`strip_hostname_suffixes` unused `maxlen` parameter removed** — Function only shortens strings in-place, never needs a max length.

---

## [1.3.1] - 2026-03-13

### Fixed
- **`set_task` used raw player ID as task ID** — Version display task now uses `TASK_VERSION_BASE` offset with cleanup on `client_disconnected`.

---

## [1.3.0] - 2026-01-24

### Removed
- **Engine hostname broadcast** - Removed feature that caused forced player respawn and menu closures
  - Hostname now updates via simple cvar change (like KTPMatchHandler)
  - New connections see updated hostname immediately
  - Existing players see update on map change/reconnect
  - No gameplay disruption

---

## [1.1.3] - 2026-01-23

### Fixed
- **Hostname caching timing** - `plugin_cfg()` also runs before server configs
  - Now uses 1-second delayed task like KTPMatchHandler

---

## [1.1.2] - 2026-01-23

### Added
- **Grenade spawn command** - `.grenade` / `.nade` to manually get a grenade
  - For classes without default grenades (sniper, MG, etc.)
  - Gives team-appropriate grenade (Allies: hand grenade, Axis: stick grenade)

---

## [1.1.0] - 2026-01-23

### Changed
- **Match detection** - Now uses `ktp_is_match_active()` native from KTPMatchHandler
  - Detects match at PRE-START phase (when .ktp/.12man/etc initiated)
  - Previously only checked for live matches

---

## [1.0.9] - 2026-01-23

### Added
- **Auto-exit on match start** - Practice mode automatically ends when match enters pre-start phase

---

## [1.0.8] - 2026-01-23

### Added
- **HUD indicator** - Green "KTP PRACTICE MODE" text at top center of screen
- **Chat reminders** - Periodic reminder every 3 minutes with available commands

---

## [1.0.4] - 2026-01-23

### Fixed
- **Map change cleanup** - Practice mode now properly ends on map change
  - Uses localinfo (`_ktp_prac`) to persist state across map changes
  - Announces practice mode end to players on new map

---

## [1.0.2] - 2026-01-23

### Fixed
- **Infinite grenades** - Now working correctly
  - Changed from `grenade_throw` to `dod_grenade_explosion` forward
  - Uses `dodx_give_grenade()` native to give weapon back

---

## [1.0.1] - 2026-01-23

### Changed
- Use `dodx_set_user_noclip()` native instead of fun module's `set_user_noclip()`
  - Enables full extension mode compatibility (no Metamod required)

### Removed
- `engine`, `fun`, `dodfun` include dependencies
  - Plugin now only requires `amxmodx`, `amxmisc`, `dodx`, `dodconst`

---

## [1.0.0] - 2026-01-22

### Added
- **Practice mode activation** - `.practice` / `.prac` commands
  - Blocked during active matches (checks KTPMatchHandler state)
  - Sets mp_timelimit to 99 minutes
  - Enables sv_cheats for noclip support
- **Infinite grenades** - Automatic refill on throw
  - Hooks `grenade_throw` forward from DODX
  - 0.1s delay ensures throw is processed first
  - Auto-detects grenade type by team/class
- **Noclip command** - `.noclip` / `.nc` toggle
  - Only available during practice mode
  - Resets on death or disconnect
- **Auto-exit on empty server** - 5-second polling interval
  - Excludes bots and HLTV from player count
- **Dynamic hostname** - Appends " - PRACTICE" suffix
  - Strips existing suffixes on plugin init
  - Restores base hostname on exit
- **Practice mode exit** - `.endpractice` / `.endprac` commands
  - Restores original mp_timelimit
  - Sets sv_cheats to 0
  - Disables noclip for all players

### Technical
- Uses DODX natives: `dodx_set_grenade_ammo()`, `dodx_get_grenade_ammo()`
- Uses DODX forward: `grenade_throw()`
- Match state detection via `_ktp_mid` localinfo

---

[1.3.0]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.3.0
[1.1.3]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.1.3
[1.1.2]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.1.2
[1.1.0]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.1.0
[1.0.9]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.9
[1.0.8]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.8
[1.0.4]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.4
[1.0.2]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.2
[1.0.1]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.1
[1.0.0]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.0

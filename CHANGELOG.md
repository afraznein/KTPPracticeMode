# KTP Practice Mode - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.0] - 2026-01-22

### Added
- **Practice mode activation** - `.practice` / `.prac` commands
  - Blocked during active matches (checks KTPMatchHandler state)
  - Sets mp_timelimit to 99 minutes
  - Enables sv_cheats for noclip support
- **Infinite grenades** - Automatic refill on throw
  - Hooks `grenade_throw` forward from dodfun
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
- Uses dodfun forward: `grenade_throw()`
- Match state detection via `_ktp_mid` localinfo

---

[1.0.0]: https://github.com/afraznein/KTPPracticeMode/releases/tag/v1.0.0

# KTP Practice Mode

**Version 1.0.0** - Practice mode plugin for Day of Defeat servers

An AMX Mod X plugin that provides a practice mode with infinite grenades, extended timelimit, noclip, and automatic cleanup when the server empties.

---

## Features

- **Infinite grenades** - Grenades refill immediately after throwing
- **Extended timelimit** - Sets mp_timelimit to 99 minutes
- **Noclip command** - All players can toggle noclip during practice
- **Auto-exit** - Automatically exits practice mode when server empties
- **Dynamic hostname** - Appends " - PRACTICE" to server name
- **Match protection** - Blocked when a KTPMatchHandler match is active

---

## Requirements

- **KTPAMXX** with DODX module (grenade ammo natives and `grenade_throw` forward)

---

## Installation

1. **Compile** the plugin:
   ```bash
   amxxpc KTPPracticeMode.sma -oKTPPracticeMode.amxx
   ```

2. **Install** to your server:
   - KTPAMXX: `addons/ktpamx/plugins/KTPPracticeMode.amxx`
   - AMX Mod X: `addons/amxmodx/plugins/KTPPracticeMode.amxx`

3. **Add to** `plugins.ini`:
   ```
   KTPPracticeMode.amxx
   ```

4. **Restart** server

---

## Commands

| Command | Description |
|---------|-------------|
| `.practice` / `.prac` | Enter practice mode (anyone, when no match active) |
| `.endpractice` / `.endprac` | Exit practice mode |
| `.noclip` / `.nc` | Toggle noclip (only during practice mode) |

---

## How It Works

### Entering Practice Mode
- Any player can type `.practice` when no match is active
- Checks `_ktp_mid` localinfo to detect active KTPMatchHandler matches
- Sets `mp_timelimit 99` and `sv_cheats 1` (required for noclip)
- Appends " - PRACTICE" to server hostname
- Starts monitoring for empty server

### Infinite Grenades
- Hooks the `grenade_throw` forward from DODX module
- When a grenade is thrown, schedules a 0.1s task to refill
- Automatically detects grenade type based on team/class:
  - US classes: Hand Grenade
  - British classes: Mills Bomb
  - Axis classes: Stick Grenade

### Noclip
- Only available during practice mode
- Requires `sv_cheats 1` (set automatically)
- Toggles on/off with each `.noclip` command
- Resets when player dies or disconnects

### Exiting Practice Mode
- Manual: Any player types `.endpractice`
- Automatic: When server empties (checked every 5 seconds)
- Restores original `mp_timelimit`
- Sets `sv_cheats 0`
- Resets hostname to base name
- Disables noclip for all players

---

## Technical Notes

- Practice mode state tracked via `g_bPracticeMode` global
- Base hostname cached at plugin init, stripping any existing suffixes
- Player noclip states tracked in `g_bPlayerNoclip[33]` array
- Empty server check excludes bots and HLTV

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## License

GPL-2.0 - See [LICENSE](LICENSE) file for details.

---

## Author

**Nein_**
- GitHub: [@afraznein](https://github.com/afraznein)
- Project: KTP Competitive Infrastructure

---

## Related Projects

- [KTPAMXX](https://github.com/afraznein/KTPAMXX) - Custom AMX Mod X fork with DODX grenade natives
- [KTPMatchHandler](https://github.com/afraznein/KTPMatchHandler) - Competitive match management
- [KTPGrenadeLoadout](https://github.com/afraznein/KTPGrenadeLoadout) - Per-class grenade configuration

# KTP Practice Mode

**Version 1.3.0** - Practice mode plugin for Day of Defeat servers

An AMX Mod X plugin that provides a practice mode with infinite grenades, extended timelimit, noclip, and automatic cleanup when the server empties or a match starts.

---

## Features

- **Infinite grenades** - Grenades refill after explosion via `dod_grenade_explosion` forward
- **Grenade spawn command** - `.grenade` for classes without default grenades
- **Extended timelimit** - Sets mp_timelimit to 99 minutes
- **Noclip command** - All players can toggle noclip during practice
- **HUD indicator** - Green "KTP PRACTICE MODE" at top of screen
- **Chat reminders** - Periodic command reminders every 3 minutes
- **Auto-exit** - Exits when server empties OR when a match starts
- **Dynamic hostname** - Appends " - PRACTICE" to server name
- **Match protection** - Blocked when KTPMatchHandler match is active (including pre-start)
- **Map change handling** - Properly cleans up and announces on map change

---

## Requirements

- **KTPAMXX 2.6.7+** with DODX module:
  - `dod_grenade_explosion` forward
  - `dodx_give_grenade()` native
  - `dodx_set_user_noclip()` native
- **KTPMatchHandler** (optional) - For `ktp_is_match_active()` native

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
| `.grenade` / `.nade` | Get a grenade (only during practice mode) |

---

## How It Works

### Entering Practice Mode
- Any player can type `.practice` when no match is active
- Uses `ktp_is_match_active()` native to detect matches (including pre-start phase)
- Sets `mp_timelimit 99` and `sv_cheats 1` (required for noclip)
- Appends " - PRACTICE" to server hostname
- Starts HUD indicator and chat reminder tasks
- Starts monitoring for empty server or match start

### Infinite Grenades
- Hooks the `dod_grenade_explosion` forward from DODX module
- When a grenade explodes, gives the same grenade type back via `dodx_give_grenade()`
- Works for all grenade types (hand, stick, Mills bomb)

### Grenade Spawn
- `.grenade` command gives team-appropriate grenade
- Useful for classes without default grenades (sniper, MG, etc.)

### Noclip
- Only available during practice mode
- Requires `sv_cheats 1` (set automatically)
- Toggles on/off with each `.noclip` command
- Resets when player dies or disconnects

### Exiting Practice Mode
- Manual: Any player types `.endpractice`
- Automatic: When server empties (checked every 5 seconds)
- Automatic: When a match starts (pre-start phase detected)
- On map change: Cleans up and announces on new map
- Restores original `mp_timelimit` and sets `sv_cheats 0`
- Resets hostname and disables noclip for all players

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

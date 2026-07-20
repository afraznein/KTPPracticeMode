# KTP Practice Mode

**Version 1.4.6** - Practice mode plugin for Day of Defeat servers

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

- **KTPAMXX 2.7.4+** with DODX module:
  - `dod_grenade_explosion` forward
  - `dodx_give_grenade()` native
  - `dodx_set_grenade_ammo()` native
  - `dodx_send_ammox()` native
  - `dodx_set_user_noclip()` native
  - `dod_get_user_class()` native

  All six are hard-linked — only `ktp_is_match_active()` sits behind the native
  filter. A DODX build missing any of them is a load failure, not a degraded mode.

  2.7.4 is a hard floor, not a recommendation: earlier builds miss the DODX
  fallback init for the first map load, so in extension mode `CPlayer` is
  uninitialized and **`.noclip` silently does nothing** on the first map.

### Optional: KTPMatchHandler

Match detection uses the `ktp_is_match_active()` native from KTPMatchHandler.
Since 1.4.6 the dependency is genuinely optional — a native filter lets the
plugin load without it:

- **With KTPMatchHandler:** practice mode is blocked while a match is live,
  pending, or in pre-start, and auto-exits when a match starts.
- **Without KTPMatchHandler:** the plugin loads normally, logs
  `KTPMatchHandler not loaded - match detection off` once per map load, and treats
  the server as match-free (no match handler means no matches). All practice
  features work — this is the standalone-server configuration.

(Before 1.4.6 the native was a hard link-time requirement and the plugin
failed to load without KTPMatchHandler.)

---

## Installation

1. **Compile** the plugin:
   ```bash
   bash compile.sh
   # test build (Tier 2 only, never staged to production):
   # KTP_TEST_MODE=1 bash compile.sh
   ```

   Use `compile.sh`, not a bare `amxxpc` invocation — the script generates
   `build_info.inc` (git short SHA + `-dirty` + UTC build time) before
   compiling. Skip it and `KTP_BUILD_SHA` falls back to `"unknown"`, so
   `amx_ktp_versions` can no longer identify what is deployed.

2. **Install** to your server:
   - `addons/ktpamx/plugins/KTPPracticeMode.amxx`

   KTPAMXX only. This plugin includes `ktp_version_reporter` and calls
   KTP-specific DODX natives (`dodx_give_grenade`, `dodx_set_user_noclip`) that
   stock AMX Mod X does not provide — it will not load there.

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
| `.endpractice` / `.endprac` | Exit practice mode (anyone — practice mode is a server-wide toggle) |
| `.noclip` / `.nc` | Toggle noclip (only during practice mode) |
| `.grenade` / `.nade` | Get a grenade (only during practice mode) |

None of the four carry an admin flag. Separately, the plugin enrols in the
fleet-wide `amx_ktp_versions` rcon (ADMIN_RCON) via the shared
`ktp_version_reporter` include — that command is not owned by this plugin.

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
- `.grenade` command gives team-appropriate grenade — Axis get the stick
  grenade, Allies the hand grenade, except British (Allies classes 21-25) who
  get the Mills Bomb
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
- Base hostname cached 1s after `plugin_cfg` (server configs run later), stripping any existing suffixes; read fresh if the cache is still empty
- Player noclip states tracked in `g_bPlayerNoclip[33]` array
- Empty server check excludes bots and HLTV

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## License

GPL-2.0

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

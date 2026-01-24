# KTPPracticeMode - Claude Code Context

## Compile Command
To compile this plugin, use:
```bash
wsl bash -c "cd '/mnt/n/Nein_/KTP Git Projects/KTPPracticeMode' && bash compile.sh"
```

This will:
1. Compile `KTPPracticeMode.sma` using KTPAMXX compiler
2. Output to `compiled/KTPPracticeMode.amxx`
3. Auto-stage to `N:\Nein_\KTP Git Projects\KTP DoD Server\serverfiles\dod\addons\ktpamx\plugins\`

## Project Structure
- `KTPPracticeMode.sma` - Main plugin source
- `compile.sh` - WSL compile script
- `compiled/` - Compiled .amxx output

## Commands
| Command | Description |
|---------|-------------|
| `.practice` / `.prac` | Enter practice mode (anyone, when no match active) |
| `.endpractice` / `.endprac` | Exit practice mode |
| `.noclip` / `.nc` | Toggle noclip (only during practice mode) |
| `.grenade` / `.nade` | Get a grenade (only during practice mode) |

## Features
- **Infinite grenades**: Refills grenade after explosion via `dod_grenade_explosion` forward
- **Grenade spawn**: `.grenade` command for classes without default grenades
- **Extended timelimit**: Sets mp_timelimit to 99 minutes
- **Noclip**: `.noclip` command available to all players during practice
- **HUD indicator**: Green "KTP PRACTICE MODE" text at top of screen
- **Chat reminders**: Periodic command reminder every 3 minutes
- **Auto-exit**: Exits when server empties OR when match starts
- **Dynamic hostname**: Appends " - PRACTICE" to server name
- **Map change handling**: Properly cleans up and announces on new map

## Dependencies
- **KTPAMXX 2.6.7+** with DODX module:
  - `dod_grenade_explosion` forward
  - `dodx_give_grenade()` native
  - `dodx_set_user_noclip()` native
- **KTPMatchHandler** (optional) - For `ktp_is_match_active()` native

## Match State Detection
Uses `ktp_is_match_active()` native from KTPMatchHandler to detect active matches.
Practice mode is blocked when a match is in progress (including pre-start phase).

## Key Files to Update on Version Bump
1. `KTPPracticeMode.sma` - `#define PLUGIN_VERSION`

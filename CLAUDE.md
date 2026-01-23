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

## Features
- **Infinite grenades**: Automatically refills grenade after each throw
- **Extended timelimit**: Sets mp_timelimit to 99 minutes
- **Noclip**: `.noclip` command available to all players during practice
- **Auto-exit**: Automatically exits practice mode when server empties
- **Dynamic hostname**: Appends " - PRACTICE" to server name

## Dependencies
- **KTPAMXX** with DODX module (`grenade_throw` forward, `dodx_set_grenade_ammo`, `dodx_get_grenade_ammo` natives)

## Match State Detection
Checks `_ktp_mid` localinfo set by KTPMatchHandler to detect active matches.
Practice mode is blocked when a match is in progress.

## Key Files to Update on Version Bump
1. `KTPPracticeMode.sma` - `#define PLUGIN_VERSION`

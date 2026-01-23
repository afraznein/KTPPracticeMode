/* KTP Practice Mode v1.0.0
 * Server practice mode with infinite grenades, extended timelimit, and noclip
 *
 * AUTHOR: Nein_
 * VERSION: 1.0.0
 * DATE: 2026-01-22
 *
 * ========== FEATURES ==========
 * - Infinite grenades (refill on throw)
 * - Extended timelimit (99 minutes)
 * - Noclip command for all players
 * - Auto-exit when all players leave
 * - Dynamic hostname (adds " - PRACTICE" suffix)
 * - Blocked during active matches (checks KTPMatchHandler state)
 *
 * ========== COMMANDS ==========
 * - .practice / .prac - Enter practice mode (anyone, when no match active)
 * - .endpractice / .endprac - Exit practice mode
 * - .noclip / .nc - Toggle noclip (only during practice mode)
 *
 * ========== REQUIREMENTS ==========
 * - KTPAMXX with DODX module (grenade natives)
 * - dodfun module (grenade_throw forward)
 *
 * ========== CHANGELOG ==========
 *
 * v1.0.0 (2026-01-22) - Initial Release
 *   + ADDED: Practice mode with infinite grenades
 *   + ADDED: Noclip toggle command
 *   + ADDED: Auto-exit when server empties
 *   + ADDED: Dynamic hostname updates
 *   + ADDED: Match state detection (blocks during active matches)
 *
 */

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>
#include <dodx>
#include <dodfun>
#include <dodconst>

#define PLUGIN_NAME    "KTP Practice Mode"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Nein_"

// Grenade weapon IDs
#define DODW_HANDGRENADE  13
#define DODW_STICKGRENADE 14
#define DODW_MILLS_BOMB   36

// Practice mode state
new bool:g_bPracticeMode = false;
new g_szBaseHostname[64];
new g_iPreviousTimelimit;

// Noclip tracking
new bool:g_bPlayerNoclip[33];

// Player count check task
#define TASK_CHECK_PLAYERS 1000
#define PLAYER_CHECK_INTERVAL 5.0

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    // Practice mode commands
    register_clcmd("say .practice", "cmd_practice");
    register_clcmd("say_team .practice", "cmd_practice");
    register_clcmd("say .prac", "cmd_practice");
    register_clcmd("say_team .prac", "cmd_practice");

    register_clcmd("say .endpractice", "cmd_endpractice");
    register_clcmd("say_team .endpractice", "cmd_endpractice");
    register_clcmd("say .endprac", "cmd_endpractice");
    register_clcmd("say_team .endprac", "cmd_endpractice");

    // Noclip command
    register_clcmd("say .noclip", "cmd_noclip");
    register_clcmd("say_team .noclip", "cmd_noclip");
    register_clcmd("say .nc", "cmd_noclip");
    register_clcmd("say_team .nc", "cmd_noclip");

    // Cache base hostname
    get_cvar_string("hostname", g_szBaseHostname, charsmax(g_szBaseHostname));
    strip_hostname_suffixes(g_szBaseHostname, charsmax(g_szBaseHostname));
}

// Forward: Grenade thrown - refill immediately if in practice mode
public grenade_throw(id, greindex, wId) {
    if (!g_bPracticeMode)
        return;

    if (!is_user_alive(id))
        return;

    // Refill the grenade that was just thrown
    // Small delay to ensure the throw is processed
    set_task(0.1, "task_refill_grenade", id + 2000);
}

public task_refill_grenade(taskid) {
    new id = taskid - 2000;

    if (!g_bPracticeMode || !is_user_alive(id))
        return;

    new team = get_user_team(id);
    new class = dod_get_user_class(id);

    // Determine grenade type based on team/class
    new grenadeType;
    if (team == 2) {  // Axis
        grenadeType = DODW_STICKGRENADE;
    } else {
        // Allies - British classes use Mills Bomb
        if (class >= 21 && class <= 25) {
            grenadeType = DODW_MILLS_BOMB;
        } else {
            grenadeType = DODW_HANDGRENADE;
        }
    }

    // Get current count and add one back
    new current = dodx_get_grenade_ammo(id, grenadeType);
    dodx_set_grenade_ammo(id, grenadeType, current + 1);
}

public cmd_practice(id) {
    // Check if match is active (via localinfo set by KTPMatchHandler)
    new matchId[64];
    get_localinfo("_ktp_mid", matchId, charsmax(matchId));

    if (matchId[0] != EOS) {
        client_print(id, print_chat, "[KTP] Cannot enter practice mode - match in progress.");
        return PLUGIN_HANDLED;
    }

    if (g_bPracticeMode) {
        client_print(id, print_chat, "[KTP] Practice mode is already active. Use .endpractice to exit.");
        return PLUGIN_HANDLED;
    }

    // Enter practice mode
    g_bPracticeMode = true;

    // Save current timelimit
    g_iPreviousTimelimit = get_cvar_num("mp_timelimit");

    // Set practice mode cvars
    set_cvar_num("mp_timelimit", 99);
    set_cvar_num("sv_cheats", 1);  // Required for noclip

    // Update hostname
    update_hostname();

    // Start player count monitoring
    set_task(PLAYER_CHECK_INTERVAL, "task_check_players", TASK_CHECK_PLAYERS, _, _, "b");

    // Announce
    new name[32];
    get_user_name(id, name, charsmax(name));
    client_print(0, print_chat, "[KTP] Practice mode ENABLED by %s", name);
    client_print(0, print_chat, "[KTP] Infinite grenades active. Use .noclip for noclip, .endpractice to exit.");

    log_amx("[KTPPracticeMode] Practice mode enabled by %s", name);

    return PLUGIN_HANDLED;
}

public cmd_endpractice(id) {
    if (!g_bPracticeMode) {
        client_print(id, print_chat, "[KTP] Practice mode is not active.");
        return PLUGIN_HANDLED;
    }

    exit_practice_mode(id);
    return PLUGIN_HANDLED;
}

public cmd_noclip(id) {
    if (!g_bPracticeMode) {
        client_print(id, print_chat, "[KTP] Noclip is only available during practice mode.");
        return PLUGIN_HANDLED;
    }

    if (!is_user_alive(id)) {
        client_print(id, print_chat, "[KTP] You must be alive to use noclip.");
        return PLUGIN_HANDLED;
    }

    // Toggle noclip
    g_bPlayerNoclip[id] = !g_bPlayerNoclip[id];

    if (g_bPlayerNoclip[id]) {
        set_user_noclip(id, 1);
        client_print(id, print_chat, "[KTP] Noclip ENABLED. Use .noclip again to disable.");
    } else {
        set_user_noclip(id, 0);
        client_print(id, print_chat, "[KTP] Noclip DISABLED.");
    }

    return PLUGIN_HANDLED;
}

// Task: Check if server is empty and auto-exit practice mode
public task_check_players() {
    if (!g_bPracticeMode)
        return;

    new playerCount = 0;
    for (new i = 1; i <= get_maxplayers(); i++) {
        if (is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i)) {
            playerCount++;
        }
    }

    if (playerCount == 0) {
        log_amx("[KTPPracticeMode] Server empty - auto-exiting practice mode");
        exit_practice_mode(0);
    }
}

exit_practice_mode(id) {
    g_bPracticeMode = false;

    // Stop player check task
    remove_task(TASK_CHECK_PLAYERS);

    // Restore cvars
    set_cvar_num("mp_timelimit", g_iPreviousTimelimit);
    set_cvar_num("sv_cheats", 0);  // Always disable cheats on exit

    // Reset all player noclip states
    for (new i = 1; i <= get_maxplayers(); i++) {
        if (g_bPlayerNoclip[i] && is_user_connected(i)) {
            set_user_noclip(i, 0);
            g_bPlayerNoclip[i] = false;
        }
    }

    // Update hostname
    update_hostname();

    // Announce
    if (id > 0) {
        new name[32];
        get_user_name(id, name, charsmax(name));
        client_print(0, print_chat, "[KTP] Practice mode DISABLED by %s", name);
        log_amx("[KTPPracticeMode] Practice mode disabled by %s", name);
    } else {
        client_print(0, print_chat, "[KTP] Practice mode DISABLED (server empty)");
        log_amx("[KTPPracticeMode] Practice mode disabled (server empty)");
    }
}

// Reset noclip when player dies
public client_death(killer, victim, wpnindex, hitplace, TK) {
    if (g_bPlayerNoclip[victim]) {
        g_bPlayerNoclip[victim] = false;
        // Noclip is already reset by death, just clear our tracking
    }
}

// Clean up when player disconnects
public client_disconnected(id) {
    g_bPlayerNoclip[id] = false;
}

// Update hostname with practice mode state
update_hostname() {
    new hostname[128];

    if (g_bPracticeMode) {
        formatex(hostname, charsmax(hostname), "%s - PRACTICE", g_szBaseHostname);
    } else {
        copy(hostname, charsmax(hostname), g_szBaseHostname);
    }

    server_cmd("hostname ^"%s^"", hostname);
    server_exec();
    log_amx("[KTPPracticeMode] Hostname updated: %s", hostname);
}

// Strip match state suffixes from hostname to get base name
strip_hostname_suffixes(hostname[], maxlen = 0) {
    #pragma unused maxlen
    // Patterns to strip (from KTPMatchHandler)
    static const patterns[][] = {
        " - PRACTICE",
        " - KTP OT - LIVE",
        " - KTP - LIVE - 1ST HALF",
        " - KTP - LIVE - 2ND HALF",
        " - KTP - PAUSED",
        " - KTP - PENDING",
        " - 12MAN - LIVE",
        " - 12MAN - PAUSED",
        " - 12MAN - PENDING",
        " - SCRIM - LIVE",
        " - SCRIM - PAUSED",
        " - SCRIM - PENDING",
        " - DRAFT - LIVE",
        " - DRAFT - PAUSED",
        " - DRAFT - PENDING",
        " - DRAFT OT - LIVE",
        " - WARMUP"
    };

    for (new i = 0; i < sizeof(patterns); i++) {
        new pos = containi(hostname, patterns[i]);
        if (pos != -1) {
            hostname[pos] = EOS;
            break;
        }
    }

    // Trim trailing spaces
    new len = strlen(hostname);
    while (len > 0 && hostname[len - 1] == ' ') {
        hostname[--len] = EOS;
    }
}

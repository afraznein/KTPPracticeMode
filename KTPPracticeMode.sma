/* KTP Practice Mode v1.3.0
 * Server practice mode with infinite grenades, extended timelimit, and noclip
 *
 * AUTHOR: Nein_
 * VERSION: 1.3.0
 * DATE: 2026-01-23
 *
 * ========== FEATURES ==========
 * - Infinite grenades (refill on explosion)
 * - Extended timelimit (99 minutes)
 * - Noclip command for all players
 * - Grenade spawn command for classes without default grenades
 * - Auto-exit when all players leave
 * - Dynamic hostname (adds " - PRACTICE" suffix)
 * - Blocked during active matches (checks KTPMatchHandler state)
 *
 * ========== COMMANDS ==========
 * - .practice / .prac - Enter practice mode (anyone, when no match active)
 * - .endpractice / .endprac - Exit practice mode
 * - .noclip / .nc - Toggle noclip (only during practice mode)
 * - .grenade / .nade - Get a grenade (only during practice mode)
 *
 * ========== REQUIREMENTS ==========
 * - KTPAMXX 2.6.6+ with DODX module (grenade natives, dod_grenade_explosion forward)
 *
 * ========== CHANGELOG ==========
 *
 * v1.3.0 (2026-01-23) - Removed Hostname Broadcast
 *   * REMOVED: Engine hostname broadcast feature (caused forced respawn + menus)
 *   * Hostname now updates via simple cvar change (like KTPMatchHandler)
 *   * New connections see updated hostname immediately
 *   * Existing players see update on map change/reconnect
 *   * No gameplay disruption
 *
 * v1.1.3 (2026-01-23) - Hostname Caching Fix (Real)
 *   * FIXED: plugin_cfg() also runs before server configs
 *   * CHANGED: Use 1-second delayed task like KTPMatchHandler does
 *
 * v1.1.2 (2026-01-23) - Grenade Spawn Command
 *   + ADDED: .grenade / .nade command to manually spawn a grenade
 *   * For classes without default grenades (sniper, MG, etc.) or if grenade is lost
 *   * Gives team-appropriate grenade (Allies: hand grenade, Axis: stick grenade)
 *
 * v1.1.0 (2026-01-23) - Pre-Start Detection via Native
 *   * CHANGED: Now uses ktp_is_match_active() native from KTPMatchHandler
 *   * Detects match at PRE-START phase (when .ktp/.12man/etc initiated)
 *
 * v1.0.9 (2026-01-23) - Auto-Exit on Match Start
 *   + ADDED: Automatically ends practice mode when match enters pre-start phase
 *
 * v1.0.8 (2026-01-23) - HUD Indicator and Chat Reminders
 *   + ADDED: Green "PRACTICE" HUD text at top center of screen
 *   + ADDED: Chat reminder every 3 minutes with available commands
 *
 * v1.0.4 (2026-01-23) - Map Change Cleanup Fix
 *   * FIXED: Practice mode now properly ends on map change with announcement
 *   * ADDED: Uses localinfo (_ktp_prac) to persist state across map changes
 *
 * v1.0.2 (2026-01-23) - Grenade Refill Fix
 *   * FIXED: Infinite grenades now working
 *   * CHANGED: Use dod_grenade_explosion forward
 *
 * v1.0.1 (2026-01-23) - Extension Mode Compatibility
 *   * CHANGED: Use dodx_set_user_noclip instead of fun module
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
#include <dodx>
#include <dodconst>

// Native from KTPMatchHandler - returns 1 if match is live, pending, or in prestart
native ktp_is_match_active();

#define PLUGIN_NAME    "KTP Practice Mode"
#define PLUGIN_VERSION "1.3.0"
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

// HUD update task
#define TASK_HUD_UPDATE 3000
#define HUD_UPDATE_INTERVAL 1.0

// Chat reminder task
#define TASK_CHAT_REMINDER 4000
#define CHAT_REMINDER_INTERVAL 180.0  // 3 minutes

// HUD sync object
new g_hudSync;

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    // Create HUD sync object for practice mode indicator
    g_hudSync = CreateHudSyncObj();

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

    // Grenade command (manual spawn)
    register_clcmd("say .grenade", "cmd_grenade");
    register_clcmd("say_team .grenade", "cmd_grenade");
    register_clcmd("say .nade", "cmd_grenade");
    register_clcmd("say_team .nade", "cmd_grenade");

    // Check if practice mode was active before map change
    new pracState[8];
    get_localinfo("_ktp_prac", pracState, charsmax(pracState));
    if (pracState[0] == '1') {
        // Practice mode was active - clean up and announce
        set_localinfo("_ktp_prac", "");

        g_bPracticeMode = false;
        set_cvar_num("sv_cheats", 0);

        // Schedule hostname restoration for after plugin_cfg
        set_task(0.5, "task_restore_hostname_after_mapchange");

        // Delayed announcement so players see it after connecting
        set_task(5.0, "task_announce_practice_ended");

        log_amx("[KTPPracticeMode] Practice mode ended due to map change (cleanup on new map)");
    }
}

public plugin_cfg() {
    // Schedule delayed hostname refresh - server configs run AFTER plugin_cfg
    set_task(1.0, "task_refresh_hostname_after_config");
}

// Delayed hostname refresh after server configs have run
public task_refresh_hostname_after_config() {
    get_cvar_string("hostname", g_szBaseHostname, charsmax(g_szBaseHostname));
    strip_hostname_suffixes(g_szBaseHostname, charsmax(g_szBaseHostname));
    log_amx("[KTPPracticeMode] Hostname cached (delayed): %s", g_szBaseHostname);
}

public task_restore_hostname_after_mapchange() {
    // Strip " - PRACTICE" if still present
    new pos = containi(g_szBaseHostname, " - PRACTICE");
    if (pos != -1) {
        g_szBaseHostname[pos] = EOS;
    }

    server_cmd("hostname ^"%s^"", g_szBaseHostname);
    server_exec();
    log_amx("[KTPPracticeMode] Hostname restored to: %s", g_szBaseHostname);
}

// Forward: Grenade exploded - give the grenade weapon back if in practice mode
public dod_grenade_explosion(id, Float:pos[3], wpnid) {
    if (!g_bPracticeMode)
        return;

    if (!is_user_connected(id) || !is_user_alive(id))
        return;

    // Give the grenade weapon back using DODX native
    dodx_give_grenade(id, wpnid);
}

public cmd_practice(id) {
    // Check if match is active (prestart, pending, or live)
    if (ktp_is_match_active()) {
        client_print(id, print_chat, "[KTP] Cannot enter practice mode - match in progress.");
        return PLUGIN_HANDLED;
    }

    if (g_bPracticeMode) {
        client_print(id, print_chat, "[KTP] Practice mode is already active. Use .endpractice to exit.");
        return PLUGIN_HANDLED;
    }

    // Enter practice mode
    g_bPracticeMode = true;

    // Set localinfo so we can detect practice mode across map changes
    set_localinfo("_ktp_prac", "1");

    // Update hostname
    update_hostname();

    // Save current timelimit
    g_iPreviousTimelimit = get_cvar_num("mp_timelimit");

    // Set practice mode cvars
    set_cvar_num("mp_timelimit", 99);
    set_cvar_num("sv_cheats", 1);  // Required for noclip

    // Start player count monitoring
    set_task(PLAYER_CHECK_INTERVAL, "task_check_players", TASK_CHECK_PLAYERS, _, _, "b");

    // Start HUD indicator
    set_task(HUD_UPDATE_INTERVAL, "task_update_hud", TASK_HUD_UPDATE, _, _, "b");

    // Start chat reminder (every 3 minutes)
    set_task(CHAT_REMINDER_INTERVAL, "task_chat_reminder", TASK_CHAT_REMINDER, _, _, "b");

    // Announce
    new name[32];
    get_user_name(id, name, charsmax(name));
    client_print(0, print_chat, "[KTP] Practice mode ENABLED by %s", name);
    client_print(0, print_chat, "[KTP] Infinite grenades. Commands: .grenade, .noclip, .endpractice");

    log_amx("[KTPPracticeMode] Practice mode enabled by %s", name);

    // Show HUD immediately
    task_update_hud();

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
        dodx_set_user_noclip(id, 1);
        client_print(id, print_chat, "[KTP] Noclip ENABLED. Use .noclip again to disable.");
    } else {
        dodx_set_user_noclip(id, 0);
        client_print(id, print_chat, "[KTP] Noclip DISABLED.");
    }

    return PLUGIN_HANDLED;
}

public cmd_grenade(id) {
    if (!g_bPracticeMode) {
        client_print(id, print_chat, "[KTP] .grenade is only available during practice mode.");
        return PLUGIN_HANDLED;
    }

    if (!is_user_alive(id)) {
        client_print(id, print_chat, "[KTP] You must be alive to get a grenade.");
        return PLUGIN_HANDLED;
    }

    // Determine grenade type based on player team
    new team = get_user_team(id);
    new wpnid;

    if (team == 1) {
        wpnid = DODW_HANDGRENADE;
    } else if (team == 2) {
        wpnid = DODW_STICKGRENADE;
    } else {
        client_print(id, print_chat, "[KTP] You must be on a team to get a grenade.");
        return PLUGIN_HANDLED;
    }

    dodx_give_grenade(id, wpnid);
    client_print(id, print_chat, "[KTP] Grenade given.");

    return PLUGIN_HANDLED;
}

// Task: Check if server is empty or match started - auto-exit practice mode
public task_check_players() {
    if (!g_bPracticeMode)
        return;

    // Check if a match has been initiated
    if (ktp_is_match_active()) {
        client_print(0, print_chat, "[KTP] Practice mode DISABLED - Match starting.");
        log_amx("[KTPPracticeMode] Match initiated - auto-exiting practice mode");
        exit_practice_mode(0);
        return;
    }

    // Check if server is empty
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

    // Clear localinfo state
    set_localinfo("_ktp_prac", "");

    // Stop all practice mode tasks
    remove_task(TASK_CHECK_PLAYERS);
    remove_task(TASK_HUD_UPDATE);
    remove_task(TASK_CHAT_REMINDER);

    // Clear HUD for all players
    ClearSyncHud(0, g_hudSync);

    // Restore cvars
    set_cvar_num("mp_timelimit", g_iPreviousTimelimit);
    set_cvar_num("sv_cheats", 0);

    // Reset all player noclip states
    for (new i = 1; i <= get_maxplayers(); i++) {
        if (g_bPlayerNoclip[i] && is_user_connected(i)) {
            dodx_set_user_noclip(i, 0);
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

// Delayed announcement for practice mode ending on map change
public task_announce_practice_ended() {
    client_print(0, print_chat, "[KTP] Practice mode DISABLED (map change). Use .practice to re-enable.");
    log_amx("[KTPPracticeMode] Announced practice mode end to players");
}

// Task: Update HUD indicator for all players
public task_update_hud() {
    if (!g_bPracticeMode)
        return;

    set_hudmessage(0, 255, 0, -1.0, 0.02, 0, 0.0, 1.5, 0.0, 0.0, -1);
    ShowSyncHudMsg(0, g_hudSync, "KTP PRACTICE MODE");
}

// Task: Periodic chat reminder about practice mode commands
public task_chat_reminder() {
    if (!g_bPracticeMode)
        return;

    client_print(0, print_chat, "[KTP] Practice mode active. Commands: .grenade, .noclip, .endpractice");
}

// Reset noclip when player dies
public client_death(killer, victim, wpnindex, hitplace, TK) {
    if (g_bPlayerNoclip[victim]) {
        g_bPlayerNoclip[victim] = false;
    }
}

// Clean up when player disconnects
public client_disconnected(id) {
    g_bPlayerNoclip[id] = false;
}

public plugin_end() {
    if (g_bPracticeMode) {
        log_amx("[KTPPracticeMode] Map changing while practice mode active - cleanup will occur on new map");
    }
}

public client_putinserver(id) {
    if (is_user_bot(id) || is_user_hltv(id))
        return;

    set_task(5.0, "task_version_display", id);
}

public task_version_display(id) {
    if (!is_user_connected(id))
        return;

    client_print(id, print_chat, "%s version %s by %s", PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
}

// Update hostname with practice mode state (simple cvar change, no broadcast)
// New connections see updated hostname immediately
// Existing players see it on map change/reconnect
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

/* KTP Practice Mode v1.4.6
 * Server practice mode with infinite grenades, extended timelimit, and noclip
 *
 * AUTHOR: Nein_
 * VERSION: 1.4.6
 * DATE: 2026-07-08
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
 * - KTPAMXX 2.7.4+ with DODX module (grenade natives, dod_grenade_explosion
 *   forward). 2.7.4 is the floor — earlier builds break .noclip on first map load.
 * - KTPMatchHandler (optional) - match detection; without it the plugin loads
 *   fine and treats "match active" as false (standalone practice server)
 *
 * ========== CHANGELOG ==========
 *
 * v1.4.6 (2026-07-08) - Truly-optional MatchHandler + noclip hygiene
 *   * FIXED: plugin failed to load when KTPMatchHandler was absent (bare
 *     native). Native filter now lets it load standalone; match detection
 *     reports "no match" in that mode (logged once per map load).
 *   * FIXED: noclip tracking flags survived map changes, so the next .noclip
 *     for that slot toggled inverted. Cleared in map-change cleanup.
 *   * FIXED: exit sweep now resets noclip for every alive player, catching
 *     players who used console `noclip` (sv_cheats is 1 during practice).
 *   * CHANGED: auto-exit defers its repeating-task removal by 0.1s instead
 *     of removing from inside the task's own callback (KTPAMXX CTask
 *     double-decrement insurance; the platform bug is fixed in 2.7.20).
 *
 * v1.4.5 (2026-07-06) - British grenade fix + timelimit leak + hostname hygiene
 *   * FIXED: .grenade gave British players the US frag — the v1.4.0 "British
 *     team" fix branched on team==3, which never occurs (DoD teams are 1/2;
 *     British = Allies classes 21-25). Now uses the class-range rule from
 *     KTPGrenadeLoadout.
 *   * FIXED: mp_timelimit leaked (stayed 99) when practice mode ended via
 *     map change — that cleanup path restored sv_cheats only.
 *   * FIXED: .practice within ~1s of a fresh server boot appended
 *     " - PRACTICE" to an empty hostname cache; update_hostname reads fresh
 *     when the cache is unpopulated.
 *   * CHANGED: map-change hostname restore reuses the shared cache-refresh
 *     task instead of duplicating the read+strip.
 *
 * v1.4.4 (2026-07-04) - KTP_TEST_MODE build variant (Tier 2 refill contract
 *   tests: amx_ktp_prac_test_enable rcon + gated entry diagnostic; production
 *   binary logic identical to 1.4.3)
 *
 * v1.4.3 (2026-07-03) - Removed ungated dod_grenade_explosion debug log
 *   (fired every grenade in live matches; refill log now failure-only)
 *
 * v1.4.2 (2026-04-25) - Adopted ktp_version_reporter shared include
 *
 * v1.4.1 (2026-04-20) - Grenade refill diagnostic logging
 *   + ADDED: log_amx in dod_grenade_explosion — entry state (id/wpnid/practice/
 *     connected/alive) + native return values (give/setammo/sendammox/ammoSlot).
 *   + ADDED: log_amx in cmd_grenade — parity diagnostics.
 *   * Purpose: narrow the 2026-04-17 ATL2 regression where auto-refill stopped
 *     working post map-change. Forward vs natives pinpointed from log output.
 *   * Low volume — only fires during practice mode. Kept permanent, not gated.
 *
 * v1.4.0 (2026-04-04) - Fix .grenade, explosion refill, and .noclip
 *   * FIXED: .grenade and explosion refill broken — game removes weapon entity
 *     when last grenade is thrown. Now always calls dodx_give_grenade to recreate
 *     the weapon slot, then dodx_set_grenade_ammo + dodx_send_ammox to set ammo.
 *   * FIXED: .noclip broken due to DODX CPlayer not initialized in extension mode.
 *     Root cause was g_pFirstEdict NULL on first map (SV_ActivateServer hook missed).
 *     Fixed in KTPAMXX 2.7.4 DODX module.
 *   * CHANGED: Requires KTPAMXX 2.7.4+ (DODX fallback init for first map load)
 *
 * v1.3.3 (2026-04-03) - Intermediate fix attempt (superseded by v1.4.0)
 *
 * v1.3.2 (2026-03-24) - Bug fixes + cleanup
 *   * FIXED: client_death noclip engine state not cleared (players respawned flying)
 *   * FIXED: Hostname restore race on map change (reads fresh at 1.5s)
 *   * FIXED: British team unhandled in .grenade (now gives Mills Bomb)
 *   * FIXED: Repeating task accumulation guard added
 *   * CHANGED: g_szBaseHostname buffer 64->128, version display removed
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
#include <ktp_version_reporter>

// Native from KTPMatchHandler - returns 1 if match is live, pending, or in prestart.
// Optional: the native filter below lets the plugin load without KTPMatchHandler.
native ktp_is_match_active();

#define PLUGIN_NAME    "KTP Practice Mode"
#define PLUGIN_VERSION "1.4.6"
#define PLUGIN_AUTHOR  "Nein_"

// Grenade weapon IDs
#define DODW_HANDGRENADE  13
#define DODW_STICKGRENADE 14
#define DODW_MILLS_BOMB   36

// Ammo slots for HUD sync (AmmoX message)
#define AMMOSLOT_HANDGRENADE   9
#define AMMOSLOT_STICKGRENADE  11

// Practice mode state
new bool:g_bPracticeMode = false;
new bool:g_bMatchHandlerPresent = true;  // false = ktp_is_match_active unresolved at load
new g_szBaseHostname[128];
new g_iPreviousTimelimit = -1;  // -1 = never saved; 0 is a legitimate saved value (no timelimit)

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

// One-shot that stops the player-check task shortly after practice exit
#define TASK_STOP_PLAYER_CHECK 5000


// HUD sync object
new g_hudSync;

public plugin_natives() {
    set_native_filter("native_filter");
}

// Lets the plugin load without KTPMatchHandler (standalone practice server).
// trap 0 = load-time resolution failure; PLUGIN_HANDLED loads anyway.
// trap 1 = a filtered native was actually called; PLUGIN_HANDLED makes it
// return 0 — same "no match active" answer the wrapper gives, so a stray
// direct call can't throw.
public native_filter(const name[], index, trap) {
    if (equal(name, "ktp_is_match_active")) {
        if (!trap)
            g_bMatchHandlerPresent = false;
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

// All match checks go through here — never call the native when it's absent
is_match_active() {
    return g_bMatchHandlerPresent ? ktp_is_match_active() : 0;
}

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
    KTP_RegisterVersion(PLUGIN_NAME, PLUGIN_VERSION);

    if (!g_bMatchHandlerPresent) {
        log_amx("[KTPPracticeMode] KTPMatchHandler not loaded - match detection off, treating server as match-free");
    }

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

#if defined KTP_TEST_MODE
    // TEST-MODE ONLY: force the practice-mode flag without a connected
    // player (production enable is the .practice chat command). Sets ONLY
    // g_bPracticeMode — no hostname/cvar/task side effects — so Tier 2 can
    // exercise the dod_grenade_explosion refill gates in isolation.
    register_concmd("amx_ktp_prac_test_enable", "cmd_test_prac_enable", ADMIN_RCON,
        "<0|1> — TEST-MODE ONLY: force the practice-mode flag");
#endif

    // Check if practice mode was active before map change
    new pracState[8];
    get_localinfo("_ktp_prac", pracState, charsmax(pracState));
    if (pracState[0] == '1') {
        // Practice mode was active - clean up and announce
        set_localinfo("_ktp_prac", "");

        g_bPracticeMode = false;
        set_cvar_num("sv_cheats", 0);

        // Noclip tracking flags persist across map changes too — a stale
        // flag makes the next .noclip for that slot toggle inverted. The
        // engine movetype is already gone with the old map, so clearing
        // the array is the whole fix.
        for (new i = 1; i < sizeof(g_bPlayerNoclip); i++) {
            g_bPlayerNoclip[i] = false;
        }

        // Restore mp_timelimit too — this path restored sv_cheats but left
        // the 99-minute practice timelimit in force on the new map. Pawn
        // globals persist across map changes in extension mode, so the
        // saved value is still valid here (it does NOT survive a full
        // server restart, but the nightly restart re-execs configs anyway).
        // -1 sentinel = never saved; 0 is a legitimate value to restore.
        if (g_iPreviousTimelimit >= 0) {
            set_cvar_num("mp_timelimit", g_iPreviousTimelimit);
            log_amx("[KTPPracticeMode] mp_timelimit restored to %d (map-change exit)", g_iPreviousTimelimit);
        }

        // Schedule hostname restoration AFTER plugin_cfg + server configs have run (1.5s)
        // This ensures g_szBaseHostname is populated correctly before we restore
        set_task(1.5, "task_restore_hostname_after_mapchange");

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
    strip_hostname_suffixes(g_szBaseHostname);
    log_amx("[KTPPracticeMode] Hostname cached (delayed): %s", g_szBaseHostname);
}

public task_restore_hostname_after_mapchange() {
    // Reuse the shared cache refresh (configs have run by the 1.5s delay),
    // then push the cleaned name — this used to duplicate the read+strip.
    task_refresh_hostname_after_config();

    server_cmd("hostname ^"%s^"", g_szBaseHostname);
    server_exec();
    log_amx("[KTPPracticeMode] Hostname restored to: %s", g_szBaseHostname);
}

#if defined KTP_TEST_MODE
public cmd_test_prac_enable(id, level, cid) {
    // register_concmd's level is not enforced at client dispatch — without this
    // guard any connected client could toggle the flag from console.
    if (!cmd_access(id, level, cid, 2))
        return PLUGIN_HANDLED;

    new buf[4];
    read_argv(1, buf, charsmax(buf));
    g_bPracticeMode = str_to_num(buf) != 0;
    log_amx("[KTPPracticeMode] TEST: practice-mode flag forced to %d", g_bPracticeMode);
    return PLUGIN_HANDLED;
}
#endif

// Forward: Grenade exploded - give the grenade weapon back if in practice mode
public dod_grenade_explosion(id, Float:pos[3], wpnid) {
#if defined KTP_TEST_MODE
    // Entry-state diagnostic (compiled out of production — the 1.4.3
    // ungated version of this line fired every grenade in live matches).
    log_amx("[KTPPracticeMode] TEST explosion_entry: id=%d wpnid=%d practice=%d connected=%d alive=%d",
        id, wpnid, g_bPracticeMode, is_user_connected(id), is_user_alive(id));
#endif
    if (!g_bPracticeMode)
        return;

    if (!is_user_connected(id) || !is_user_alive(id))
        return;

    // Refill grenade: give weapon entity (in case slot was removed) then set ammo + sync HUD
    new give_ret = dodx_give_grenade(id, wpnid);
    new setammo_ret = dodx_set_grenade_ammo(id, wpnid, 1);
    new ammoSlot = (wpnid == DODW_STICKGRENADE) ? AMMOSLOT_STICKGRENADE : AMMOSLOT_HANDGRENADE;
    new sendammox_ret = dodx_send_ammox(id, ammoSlot, 1);

    // Log only when a refill step fails
    if (!give_ret || !setammo_ret || !sendammox_ret) {
        log_amx("[KTPPracticeMode] refill FAILED: id=%d wpnid=%d give=%d setammo=%d sendammox=%d ammoSlot=%d",
            id, wpnid, give_ret, setammo_ret, sendammox_ret, ammoSlot);
    }
}

public cmd_practice(id) {
    // Check if match is active (prestart, pending, or live)
    if (is_match_active()) {
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

    // Start player count monitoring (remove first to prevent accumulation on edge cases)
    remove_task(TASK_CHECK_PLAYERS);
    set_task(PLAYER_CHECK_INTERVAL, "task_check_players", TASK_CHECK_PLAYERS, _, _, "b");

    // Start HUD indicator
    remove_task(TASK_HUD_UPDATE);
    set_task(HUD_UPDATE_INTERVAL, "task_update_hud", TASK_HUD_UPDATE, _, _, "b");

    // Start chat reminder (every 3 minutes)
    remove_task(TASK_CHAT_REMINDER);
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

    // Determine grenade type. DoD has only teams 1/2 — British play on the
    // Allies side as classes 21-25 (the old team==3 branch was dead code, so
    // British always got the US frag). Same class-range rule as
    // KTPGrenadeLoadout.
    new team = get_user_team(id);
    new wpnid;

    if (team == 2) {
        wpnid = DODW_STICKGRENADE;
    } else if (team == 1) {
        new class = dod_get_user_class(id);
        wpnid = (class >= 21 && class <= 25) ? DODW_MILLS_BOMB : DODW_HANDGRENADE;
    } else {
        client_print(id, print_chat, "[KTP] You must be on a team to get a grenade.");
        return PLUGIN_HANDLED;
    }

    // Give weapon entity (creates pickup if slot was removed after throwing last grenade)
    // then set ammo + sync HUD
    new give_ret = dodx_give_grenade(id, wpnid);
    new setammo_ret = dodx_set_grenade_ammo(id, wpnid, 1);
    new ammoSlot = (wpnid == DODW_STICKGRENADE) ? AMMOSLOT_STICKGRENADE : AMMOSLOT_HANDGRENADE;
    new sendammox_ret = dodx_send_ammox(id, ammoSlot, 1);
    client_print(id, print_chat, "[KTP] Grenade given.");

    log_amx("[KTPPracticeMode] cmd_grenade: id=%d team=%d wpnid=%d give=%d setammo=%d sendammox=%d ammoSlot=%d",
        id, team, wpnid, give_ret, setammo_ret, sendammox_ret, ammoSlot);

    return PLUGIN_HANDLED;
}

// Task: Check if server is empty or match started - auto-exit practice mode
public task_check_players() {
    if (!g_bPracticeMode)
        return;

    // Check if a match has been initiated
    if (is_match_active()) {
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

    // Stop practice mode tasks. TASK_CHECK_PLAYERS may be the caller (auto-exit
    // runs inside it) — removing a repeating task from its own callback trips
    // the KTPAMXX CTask double-decrement (fixed in 2.7.20; deferring the
    // removal 0.1s is cheap insurance). The other two are never the caller.
    remove_task(TASK_STOP_PLAYER_CHECK);
    set_task(0.1, "task_stop_player_check", TASK_STOP_PLAYER_CHECK);
    remove_task(TASK_HUD_UPDATE);
    remove_task(TASK_CHAT_REMINDER);

    // Clear HUD for all players
    ClearSyncHud(0, g_hudSync);

    // Restore cvars (-1 sentinel = never saved; symmetric with the
    // map-change exit path)
    if (g_iPreviousTimelimit >= 0)
        set_cvar_num("mp_timelimit", g_iPreviousTimelimit);
    set_cvar_num("sv_cheats", 0);

    // Reset noclip for every alive player, not just tracked ones — sv_cheats
    // is 1 during practice, so console `noclip` users exist outside
    // g_bPlayerNoclip[]. Safe as a blanket: setting an alive walker back to
    // MOVETYPE_WALK is a no-op. Alive-only — forcing WALK on a dead or
    // observing player would be wrong.
    for (new i = 1; i <= get_maxplayers(); i++) {
        if (is_user_connected(i) && is_user_alive(i)) {
            dodx_set_user_noclip(i, 0);
        }
        g_bPlayerNoclip[i] = false;
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

// Deferred stop for the player-check task (see exit_practice_mode).
// The re-enable guard matters: if .practice ran again inside the 0.1s
// window, TASK_CHECK_PLAYERS is live again and must not be killed.
public task_stop_player_check() {
    if (!g_bPracticeMode) {
        remove_task(TASK_CHECK_PLAYERS);
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

// Reset noclip when player dies — must clear BOTH engine state and tracking flag
// so exit_practice_mode doesn't skip this player
public client_death(killer, victim, wpnindex, hitplace, TK) {
    if (g_bPlayerNoclip[victim]) {
        dodx_set_user_noclip(victim, 0);
        g_bPlayerNoclip[victim] = false;
    }
}

public plugin_end() {
    if (g_bPracticeMode) {
        log_amx("[KTPPracticeMode] Map changing while practice mode active - cleanup will occur on new map");
    }
}

public client_disconnected(id) {
    g_bPlayerNoclip[id] = false;
}

// Update hostname with practice mode state (simple cvar change, no broadcast)
// New connections see updated hostname immediately
// Existing players see it on map change/reconnect
update_hostname() {
    // The base-hostname cache fills at plugin_cfg+1.0s — on a fresh server
    // boot a .practice inside that window would append " - PRACTICE" to an
    // empty base. Read fresh instead of trusting an unpopulated cache.
    if (!g_szBaseHostname[0]) {
        get_cvar_string("hostname", g_szBaseHostname, charsmax(g_szBaseHostname));
        strip_hostname_suffixes(g_szBaseHostname);
    }

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
strip_hostname_suffixes(hostname[]) {
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

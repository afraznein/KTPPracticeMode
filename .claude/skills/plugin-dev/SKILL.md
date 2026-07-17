---
name: plugin-dev
description: Use BEFORE writing or modifying any KTPPracticeMode Pawn code — the optional-dependency contract with KTPMatchHandler, the auto-exit reason-overload trap, grenade-native failure handling, and the compile/review/stage/verify workflow. Also use when planning a change, to know which invariants it touches.
---

# KTPPracticeMode Development

This plugin runs on a production fleet (24 instances) with active players.
Follow every rule below; when a rule and your instinct disagree, the rule wins
— each one was paid for with a production incident or a review finding.

## Hard safety rules
- **NEVER restart game servers** or issue LinuxGSM control commands without the
  operator's explicit permission in the current conversation.
- Deploys are staged as `KTPPracticeMode.amxx.new` in each instance's plugins dir
  and swap at the 03:00 ET nightly restart. Never hot-swap the live `.amxx`.
- Run the `ktp-code-review` agent on any nontrivial change BEFORE compiling for deploy.

## Architecture constraints
- **Extension mode**: KTPAMXX loads as a ReHLDS extension — there is NO Metamod and
  NO fakemeta. Engine/DODX interaction comes only through DODX natives
  (`dodx_give_grenade`, `dodx_set_grenade_ammo`, `dodx_send_ammox`,
  `dodx_set_user_noclip`) and the `dod_grenade_explosion` forward. Never add a
  fakemeta/engine-module dependency.
- Pawn globals persist for the life of the process, not per map — anything that
  needs a per-map reset (noclip tracking, saved `mp_timelimit`) must be cleared
  explicitly in the map-change cleanup path, not assumed to reinit.
- **KTPMatchHandler is OPTIONAL, not a hard dependency.** Match detection goes
  through `ktp_is_match_active()` behind a `plugin_natives` / `set_native_filter`
  registration (since 1.4.6). If the native is unresolved, treat the server as
  match-free — log it once per map load, don't fail plugin load. Never call a
  KTPMatchHandler native directly without going through that filtered path.

## The auto-exit reason trap
`exit_practice_mode(id)` currently overloads `id==0` to mean two unrelated
triggers: a genuine empty-server auto-exit, and a match-starting auto-exit.
Both fall into the same branch, so a match starting while players are still
connected prints/logs the "server empty" message even though the server isn't
empty. If you touch `exit_practice_mode` or add a new auto-exit trigger:
- Give it a real reason, not another `id==0` caller (an enum or explicit
  `reason` parameter). Don't perpetuate the overload.
- Don't let the callee's generic message fire when the caller already knows
  and announced the specific reason.

## Grenade-native return values are not decorative
`dodx_give_grenade`, `dodx_set_grenade_ammo`, and `dodx_send_ammox` all
document `0` as a real failure return. `.grenade` currently prints
`"Grenade given."` to the player unconditionally, before those return values
are even checked — a failed give is reported as a success, with only a
server-log line (invisible to the player) marking the failure. `dod_grenade_explosion`'s auto-refill already does this right (checks
`!give_ret` etc. before deciding what happened) — copy that pattern, not the
`.grenade` one, in any new code that calls these natives. Note
`dodx_give_grenade` also returns `-1` for a benign non-failure case — don't
treat every non-1 return as an error without checking which native it came
from.

## Hostname suffix list: shared state, not shared code
`strip_hostname_suffixes()` here and `extract_base_hostname()` in
KTPMatchHandler are two hand-maintained copies of the same pattern array, and
they have already drifted (MatchHandler's list is ahead by several entries —
diff both arrays before trusting either one). If you change one, check the
other. If you're touching this area for real, prefer factoring the pattern
list into a shared include both plugins consume, rather than adding a fourth
place it can drift from.

## Logging discipline
Refill/grenade logging is **failure-only**. An earlier ungated per-grenade
debug log line ran on every grenade explosion in live matches and became a
stall-frame source under the fleet's file-write bottleneck — don't reintroduce
unconditional per-event logging on a path this hot (every grenade explosion,
on every instance, every match).

## Pawn checklist (apply to every diff)
- `charsmax(buf)` for every format/copy; watch truncation on composed strings.
- Every `set_task` with an id: unique id range, `remove_task` on disconnect AND
  on every teardown/map-change exit. Deferring a task's own self-removal by one
  tick (rather than removing from inside its own callback) avoids the KTPAMXX
  CTask double-decrement class of bug — a still-live platform hazard on older
  KTPAMXX, belt-and-suspenders even though the 2.7.20 core fix is fleet-wide.
- Check return values of natives that can fail (dodx grenade/noclip natives,
  file/curl/localinfo reads) — see the grenade-native rule above.
- Comments: short, explain *why*, no ticket/finding IDs, never delete a
  tripwire fact while editing near it.

## Workflow
1. **Version bump** (every shipped change): `#define PLUGIN_VERSION` in the
   .sma, new `CHANGELOG.md` section, README header version.
2. **Compile**: `wsl bash -c "cd '/mnt/n/Nein_/KTP Git Projects/KTPPracticeMode' && bash compile.sh"`
   (outputs `compiled/`, auto-stages to the KTP DoD Server test tree).
3. **Test-mode build** for the Tier-2 grenade-refill contract tests:
   `KTP_TEST_MODE=1 bash compile.sh` → `compiled/test/` (adds
   `amx_ktp_prac_test_enable` rcon + gated entry diagnostics; production
   binary is byte-identical without the flag). This variant is dormant by
   design — it exists for the Tier-2 runner, not for fleet deploy.
4. **Review**: `ktp-code-review` agent before any fleet stage.
5. **Fleet stage**: deploy as `.new` via paramiko (see root CLAUDE.md § SSH);
   verify staged md5 on all 24 active instances.
6. **Post-activation verify** (after the nightly): 24/24 on the new md5, no
   leftover `.new`, and check `/tmp` for cores — `find /tmp -maxdepth 1 -name
   'core.*' -mtime -1` on every host. A game-tree core search proves nothing
   (matches only core.so/core.ini/core.wav).

## Known open findings (not yet fixed — don't rediscover, don't accidentally fix silently)
- Auto-exit's `id==0` reason overload (see above) prints a false "server
  empty" message on match-start auto-exit.
- `.grenade` reports success unconditionally regardless of native return
  values (see above).
- `strip_hostname_suffixes()` is missing 3 entries KTPMatchHandler's copy has
  (`" - KTP OT - PENDING"`, `" - KTP OT - PAUSED"`, `" - KTP Match In
  Progress"`) — no confirmed live trigger, but the drift itself is the hazard.

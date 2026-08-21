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
  (`dodx_give_grenade`, `dodx_set_grenade_ammo`, `dodx_set_user_noclip`) and the
  `dod_grenade_explosion` forward. Never add a fakemeta/engine-module dependency.
  **Do not send AmmoX by hand.** 1.4.9 removed the last `dodx_send_ammox` call:
  DODX 2.7.29 stopped writing `m_rgAmmoLast`, so the DLL's own `SendAmmoUpdate`
  diffs the pair each frame and emits for the slot it actually wrote. A plugin
  message is a second, unsynchronised writer of the same client counter.
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
`dodx_give_grenade` and `dodx_set_grenade_ammo` both document `0` as a real
failure return. Both `.grenade` and `dod_grenade_explosion`'s auto-refill now
check them before deciding what happened (`.grenade` printed
`"Grenade given."` unconditionally until 1.4.8, reporting a failed give as a
success) — copy that pattern in any new code that calls these natives, and gate
the player-visible message on the natives that actually decide the outcome.
`dodx_give_grenade` can also return `-1`, and **its meaning is not settled.**
This file used to call it a benign non-failure case; `CHANGELOG.md`'s 1.4.8 entry
reaches the opposite conclusion from a corpus that turned out to belong to
KTPGrenadeLoadout, where the call is gated such that its `-1`s are unambiguous
failures. The shipped behaviour is deliberately narrower than either reading:
judge the strict `0`/`1` returns and leave `-1` explicitly unjudged. Read that
changelog entry before building any check on `-1` — the first attempt at a fix
here was rejected in review for relying on the benign reading. Separately, 2.7.29 changed `dodx_get_grenade_ammo`'s failure return from
`0` to `-1`, so an `== 0` test on a *count* no longer catches an unreadable
one.

## Hostname suffix list: shared state, not shared code
`strip_hostname_suffixes()` here and `extract_base_hostname()` in
KTPMatchHandler are two hand-maintained copies of the same pattern array, and
they have already drifted (MatchHandler's list is ahead by several entries —
diff both arrays before trusting either one). If you change one, check the
other. If you're touching this area for real, prefer factoring the pattern
list into a shared include both plugins consume, rather than adding a fourth
place it can drift from.

**The suffix text is an interface, not presentation.** Hostname-derived
identifiers elsewhere in the stack consume whatever this appends, and whitespace
inside a suffix has already propagated into a match ID and made HLTV reject its
`record` command outright — recording then silently did not happen while practice
mode was active. Treat spacing and punctuation in these patterns as load-bearing,
and check what downstream derives from the hostname before changing one.

## Logging discipline
Refill/grenade logging is **failure-only**. An earlier ungated per-grenade
debug log line ran on every grenade explosion in live matches and became a
stall-frame source under the fleet's file-write bottleneck — don't reintroduce
unconditional per-event logging on a path this hot (every grenade explosion,
on every instance, every match).

**The failure-only line that remains is detection infrastructure, not leftover
diagnostics — don't tidy it away.** The contract tests stop at the practice-mode
gate, and when the gate fails the refill natives never run, so "a refill native
returned zero" is structurally unreachable from the suite; that log line is the
only thing that would ever surface it. Know its blind spot too: if every native
reports success and no grenade actually appears, nothing logs at all and a player
noticing is the only signal. Because the section above is otherwise about what
must *not* be logged, a future reader has every reason to mistake this line for
more of the same.

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

## Never run a destructive simulation inside the working tree
Verifying a fix often means simulating the failure — writing a fake `build.sh`, a
fake artifact, a fake staging dir. Do it in a **verified** scratch dir, never in
the repo:

```bash
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1   # verify BEFORE you cd — this is the whole rule
cd "$T" || exit 1
```

`cd "$T"` with an empty `$T` **silently succeeds and leaves you where you were** —
in the repo. A simulation that then writes `build.sh` overwrites the real one. On
2026-07-16 exactly that truncated a tracked 60-line upstream file to 2 lines and
dropped a junk `.so` into `build/`, where a `find | head -1` could have staged it.
It was caught only because `git status` showed a modification nobody made.

So: verify the scratch dir before `cd`, and **run `git status` after any test that
touches the filesystem** — an unexpected change is the tell. Prefer copying inputs
out to the scratch dir over running tools "in place".

## Workflow
1. **Version bump** (every shipped change): `#define PLUGIN_VERSION` in the
   .sma, new `CHANGELOG.md` section, README header version.
2. **Compile**: `wsl bash -c "cd '/mnt/n/Nein_/KTP Git Projects/KTPPracticeMode' && bash compile.sh"`
   (outputs `compiled/`, auto-stages to the KTP DoD Server test tree).
3. **Test-mode build** for the Tier-2 grenade-refill contract tests:
   `KTP_TEST_MODE=1 bash compile.sh` → `compiled/test/` (adds
   `amx_ktp_prac_test_enable` — a test-build console command registered at
   level `-1` with no `cmd_access` check, so any connected client can call it
   in a test build; never stage one to production — plus gated entry
   diagnostics; production
   binary is byte-identical without the flag). This variant is dormant by
   design — it exists for the Tier-2 runner, not for fleet deploy.
4. **Review**: `ktp-code-review` agent before any fleet stage.
5. **Fleet stage**: deploy as `.new` via paramiko (see root CLAUDE.md § SSH);
   verify staged md5 on all 24 active instances.
6. **Post-activation verify** (after the nightly): 24/24 on the new md5, no
   leftover `.new`, and check `/tmp` for cores — `find /tmp -maxdepth 1 -name
   'core.*' -mtime -1` on every host. A game-tree core search proves nothing
   (matches only core.so/core.ini/core.wav).

⚠️ **A grenade or noclip fix cannot be validated after a `changelevel`.** The
root cause this whole area was built around was a module-side initialisation that
never ran on the first map of a process, so the player-manipulation natives
silently no-opped until the first map change. A test run after a `changelevel`
therefore exercises the already-healthy path and passes without ever touching the
bug. Exercise all three lifecycle shapes: the map the server booted into, a
`changelevel` away from it, and a `changelevel` from an already-changed map.

## Known open findings (not yet fixed — don't rediscover, don't accidentally fix silently)
- Auto-exit's `id==0` reason overload (see above) prints a false "server
  empty" message on match-start auto-exit.
- `strip_hostname_suffixes()` is missing 3 entries KTPMatchHandler's copy has
  (`" - KTP OT - PENDING"`, `" - KTP OT - PAUSED"`, `" - KTP Match In
  Progress"`) — no confirmed live trigger, but the drift itself is the hazard.

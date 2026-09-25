# Redot 26.3 RC1 source-runtime validation

Target: Redot `26.3.rc.1.official.704b10a8e`, Windows 10 x64. Run each script with an isolated user profile, `--headless`, and a bounded `--quit-after` of at least 2. No live Twitch credentials are needed for these fixtures. These results are not editor-import, exported-game, or live-service certification.

| Script | Latest result | Strict shutdown gate |
| --- | --- | --- |
| `tests/eventsub_lifecycle.gd` | 14/14 checks; ownership cleanup, pending retry cancellation, close/reopen and direct free | PASS, no diagnostics |
| `tests/eventsub_up05.gd` | 24/24 watchdog, handover, dedupe, and cleanup checks | PASS, no diagnostics |
| `tests/redot_compatibility.gd` | Compatibility probe passes its assertions | PASS, no diagnostics |

The load-only and add/free EventSub isolation probes also exit cleanly on this source. Previously they retained 76 and 77 resources respectively. Generated EventSub response scripts are now resolved on demand; definition objects are reference-counted; unparented WebSocket clients are freed with their owner. The subsequent ObjectDB warning had two further causes: static `TwitchScope.Definition` objects used manual ownership, and a pending WebSocket connection timer left its coroutine suspended when the client was freed. Scope definitions now use `RefCounted`; close/tree exit resumes the pending wait after invalidating its generation, so it cannot reconnect. Independent isolated Windows retests of direct scope/plugin load, early-free cancellation and all three scripts above passed without warnings. The warning was repaired, not filtered or waived.

The lifecycle regression closes/reopens a client before the old timer fires, verifies that the stale timer cannot dial, and frees an in-tree pending client without an explicit close. Connection timing, public APIs, scope data and editor styles are unchanged. Historical failing evidence remains in the remediation campaign; these results supersede the previous 10-check lifecycle and warning-bearing UP-05/compatibility results.

One broader static-tool discrepancy remains recorded separately: project-tools `check_project` reports 498/498 loaded but emits a missing-external-script diagnostic for `page_overlay_authorization.tscn`. The referenced script exists and the compatibility probe loads the scene. Its contradictory summary is not accepted as a clean whole-project static gate, and no unrelated scene/tooling change was made in this repair.

Redot 26.3 RC1 headless editor import separately crashes on this Windows environment, including with an empty project; use an existing completed import cache for the script fixtures while that engine issue is handled separately. No engine files were changed by this ObjectDB repair.

The existing Linux GitHub compatibility workflow now targets the same 26.3 RC1 release, checks the official asset SHA-256 and exact version, and uses bounded import/probe commands. It fails on warnings as well as errors; a CI pass is not presumed from the local assertion results. Live-service and exported-game gates remain separate.

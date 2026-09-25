# Redot 26.3 RC1 source-runtime validation

Target: Redot `26.3.rc.1.official.704b10a8e`, Windows 10 x64. Run each script with an isolated user profile, `--headless`, and a bounded `--quit-after` of at least 2. No live Twitch credentials are needed for these fixtures. These results are not editor-import, exported-game, or live-service certification.

| Script | Latest result | Strict shutdown gate |
| --- | --- | --- |
| `tests/eventsub_lifecycle.gd` | 10/10 checks; definition response script resolves; never-entered, reattached, and test-mode clients free correctly | PASS, no diagnostics |
| `tests/eventsub_up05.gd` | 24/24 watchdog, handover, dedupe, and cleanup checks | FAIL: ObjectDB warning, no resource leak |
| `tests/redot_compatibility.gd` | Compatibility probe passes its assertions | FAIL: ObjectDB warning, no resource leak |

The load-only and add/free EventSub isolation probes also exit cleanly on this source. Previously they retained 76 and 77 resources respectively. Generated EventSub response scripts are now resolved on demand; definition objects are reference-counted; unparented WebSocket clients are freed with their owner. The remaining broad-suite ObjectDB warning has not been attributed to a specific object, so it is not waived. Redot 26.3 RC1 headless editor import separately crashes on this Windows environment, including with an empty project; use an existing completed import cache for the script fixtures while investigating that engine issue.

The existing Linux GitHub compatibility workflow now targets the same 26.3 RC1 release, checks the official asset SHA-256 and exact version, and uses bounded import/probe commands. It fails on warnings as well as errors; a CI pass is not presumed from the local assertion results. Live-service and exported-game gates remain separate.

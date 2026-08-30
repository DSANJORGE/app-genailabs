# TestU domain glossary

Terms the code and design artifacts use with a precise meaning. Keep code
identifiers aligned with these names.

## Learn Mode session

- **Session engine** — the deep module behind a Learn Mode session
  (`lib/testu/testu_session_engine.dart`): flow, verdicts, pacing, gating
  and outcome, with no Flutter widgets. The screen in `testu_session.dart`
  is its rendering adapter.
- **SessionController** — the engine's single concrete class. Eight
  mutators + four getters drive the whole session; mutators outside their
  legal phase are silent no-ops.
- **SessionScheduler** — the internal seam for time. Two adapters:
  `TimerScheduler` in production, `FakeScheduler` in tests. The engine owns
  its pacing; `dispose` guarantees nothing fires afterwards.
- **SessionEntry** — one semantic transcript item (framing, prompt, hint
  note, verdict, continue offer, stop challenge, farewell). Entries carry
  data, never spans or widgets — that's what keeps mid-session language
  switching live for the whole transcript, past bubbles included.
- **Attempt** — one answered question: chosen option, confidence (0
  guessing … 3 certain), correct, and **assisted** (a hint was used;
  recorded and shown plainly, no mastery weighting until the backend
  defines one).
- **SessionOutcome** — the session's real result (attempts + completed
  flag). Feeds the debrief; `completed == false` means the learner stopped
  early and the debrief says so.
- **HapticIntent** — the verdict's physical feedback as *data*
  (medium = correct, heavy = wrong). The engine returns it; only the UI
  shell performs it.
- **judge** — the pure verdict function, the engine's second internal seam.

## Debrief vocabulary

Per-attempt finding categories, computed from real outcome data:

- **Reinforced** — correct while fairly sure or certain.
- **Fragile** — correct but unsure/guessing; may not be consolidated.
- **Misconception** — incorrect while certain; the most valuable finding.
- **To review** — incorrect with lower confidence.
- **Calibration** — share of attempts where confidence matched correctness
  (conf ≥ 2 ⟺ correct). Placeholder formula until the backend's model.

## Confidence gate

The first confidence tap ever shows the tap-submits explainer and swallows
the tap (`needsConfAck` / `acknowledgeConf`). Acknowledgement persists via
SharedPreferences (`testu.confAcked`) — show-once-ever, not once-per-run.
The swallow rule lives in the engine; storage lives in the adapter.

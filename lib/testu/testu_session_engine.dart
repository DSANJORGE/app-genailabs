import 'dart:async';

import 'package:flutter/foundation.dart';

/// Session engine — all Learn Mode flow, verdicts, pacing and gating, with
/// no Flutter widgets. The screen in testu_session.dart is a rendering
/// adapter over [SessionController]; tests drive the controller directly.
///
/// Design: Traycer artifact `session-engine-design` (Design B).

/// Internal seam for time. Two adapters: [TimerScheduler] (production) and
/// the test FakeScheduler.
abstract interface class SessionScheduler {
  void after(Duration d, void Function() fn);
  void cancelAll();
}

class TimerScheduler implements SessionScheduler {
  final _pending = <Timer>{};

  @override
  void after(Duration d, void Function() fn) {
    late final Timer t;
    t = Timer(d, () {
      _pending.remove(t);
      fn();
    });
    _pending.add(t);
  }

  @override
  void cancelAll() {
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
  }
}

enum HapticIntent { medium, heavy }

/// What the engine needs to know about a question — language-independent,
/// so the injected getter can re-read live question data without the engine
/// caring which language the copy is in.
class SessionQuestion {
  const SessionQuestion({required this.okIdx, this.video = false});

  final int okIdx;
  final bool video;
}

class Attempt {
  const Attempt({
    required this.qi,
    required this.chosen,
    required this.confidence,
    required this.correct,
    required this.assisted,
  });

  final int qi;
  final int chosen;
  final int confidence; // 0 guessing … 3 certain
  final bool correct;
  final bool assisted; // a hint was used before answering
}

class SessionOutcome {
  const SessionOutcome({required this.attempts, required this.completed});

  final List<Attempt> attempts;
  final bool completed; // false when the learner stopped early
}

/// Pure verdict: internal seam, unit-testable without the controller.
Attempt judge(
  SessionQuestion q, {
  required int qi,
  required int chosen,
  required int confidence,
  required bool assisted,
}) =>
    Attempt(
      qi: qi,
      chosen: chosen,
      confidence: confidence,
      correct: chosen == q.okIdx,
      assisted: assisted,
    );

/// Semantic transcript — no spans or widgets; the adapter builds visuals
/// from these at build time, which is what keeps mid-session language
/// switching live for the whole transcript.
sealed class SessionEntry {
  const SessionEntry();
}

class Framing extends SessionEntry {
  const Framing({required this.qi, required this.video});
  final int qi;
  final bool video;
}

class Prompt extends SessionEntry {
  const Prompt({required this.qi});
  final int qi;
}

class HintNote extends SessionEntry {
  const HintNote({required this.qi});
  final int qi;
}

class Verdict extends SessionEntry {
  const Verdict(this.attempt);
  final Attempt attempt;
}

class ContinueOffer extends SessionEntry {
  const ContinueOffer({required this.last});
  final bool last;
}

class StopChallenge extends SessionEntry {
  const StopChallenge({required this.remaining});
  final int remaining;
}

class StopFarewell extends SessionEntry {
  const StopFarewell();
}

enum _Phase {
  idle,
  opening,
  framing,
  answering,
  verdict,
  offered,
  stopChallenged,
  ended,
}

/// Deep module: the whole session lifecycle behind 8 mutators + 4 getters.
/// Mutators outside their legal phase are silent no-ops (double-tap safe);
/// out-of-range arguments throw — that is a caller bug, not a user race.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.questions,
    required this._scheduler,
    required this._confAcked,
  });

  /// Getter, not a list: question data stays live across language switches.
  final List<SessionQuestion> Function() questions;
  final SessionScheduler _scheduler;

  bool _confAcked;
  bool _disposed = false;
  _Phase _phase = _Phase.idle;
  _Phase? _preStop; // phase to restore if a mid-question stop is waved off
  int _qi = 0;
  bool _assisted = false;
  double _progress = 0.05;
  final _transcript = <SessionEntry>[];
  final _attempts = <Attempt>[];
  SessionOutcome? _outcome;

  List<SessionEntry> get transcript => List.unmodifiable(_transcript);
  double get progress => _progress;

  /// While true, [submit] swallows the tap; the adapter shows the
  /// tap-submits explainer and calls [acknowledgeConf] from its button.
  bool get needsConfAck => !_confAcked;

  /// Anything answered yet? Nothing to challenge a stop with if not.
  bool get hasProgress => _attempts.isNotEmpty;

  /// Null until the session ends; transitions null → value exactly once.
  SessionOutcome? get outcome => _outcome;

  // Pacing verbatim from the prototype.
  static const _opener = Duration(milliseconds: 300);
  static const _framingToPrompt = Duration(milliseconds: 1450);
  static const _verdictToOffer = Duration(milliseconds: 2100);
  static const _completeToDebrief = Duration(milliseconds: 350);
  static const _farewellToDebrief = Duration(milliseconds: 1900);

  void start() {
    if (_phase != _Phase.idle) return;
    _phase = _Phase.opening;
    _scheduler.after(_opener, _frame);
  }

  void _frame() {
    final qs = questions();
    _phase = _Phase.framing;
    _progress = 0.08 + (_qi / qs.length) * 0.90;
    _add(Framing(qi: _qi, video: qs[_qi].video));
    if (!qs[_qi].video) _scheduler.after(_framingToPrompt, _prompt);
  }

  void watchedVideo() {
    if (_phase != _Phase.framing || !questions()[_qi].video) return;
    _prompt();
  }

  void _prompt() {
    _phase = _Phase.answering;
    _assisted = false;
    _add(Prompt(qi: _qi));
  }

  void markHintUsed() {
    if (_phase != _Phase.answering) return;
    _assisted = true;
    _add(HintNote(qi: _qi));
  }

  HapticIntent? submit({required int chosen, required int confidence}) {
    if (chosen < 0 || confidence < 0 || confidence > 3) {
      throw ArgumentError('chosen=$chosen confidence=$confidence');
    }
    if (_phase != _Phase.answering) return null;
    if (!_confAcked) return null; // first-tap gate: swallowed, not an error
    final a = judge(questions()[_qi],
        qi: _qi, chosen: chosen, confidence: confidence, assisted: _assisted);
    _attempts.add(a);
    _phase = _Phase.verdict;
    _add(Verdict(a));
    _scheduler.after(_verdictToOffer, () {
      _phase = _Phase.offered;
      _add(ContinueOffer(last: _qi >= questions().length - 1));
    });
    return a.correct ? HapticIntent.medium : HapticIntent.heavy;
  }

  void acknowledgeConf() {
    if (_confAcked) return;
    _confAcked = true;
    _notify();
  }

  void continueSession() {
    if (_phase != _Phase.offered && _phase != _Phase.stopChallenged) return;
    // The challenge can now come mid-question (header ✕). "Keep going" must
    // hand the learner back the question they were on, not skip it.
    if (_preStop != null) {
      _phase = _preStop!;
      _preStop = null;
      _notify();
      return;
    }
    _qi++;
    if (_qi >= questions().length) {
      _phase = _Phase.ended;
      _progress = 1.0;
      _notify();
      _scheduler.after(_completeToDebrief, () => _finish(completed: true));
    } else {
      _frame();
    }
  }

  /// True when the challenge was raised (and the adapter should stay put);
  /// false when there is nothing to challenge — the caller may just leave.
  bool requestStop() {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.opening:
      case _Phase.stopChallenged:
      case _Phase.ended:
        return false;
      case _Phase.offered:
        break; // end-of-question stop: "Keep going" advances, as before
      case _Phase.framing:
      case _Phase.answering:
      case _Phase.verdict:
        _preStop = _phase; // mid-question: "Keep going" returns here
    }
    _phase = _Phase.stopChallenged;
    _add(StopChallenge(remaining: questions().length - 1 - _qi));
    return true;
  }

  void confirmStop() {
    if (_phase != _Phase.stopChallenged) return;
    _preStop = null;
    _phase = _Phase.ended;
    _add(const StopFarewell());
    _scheduler.after(_farewellToDebrief, () => _finish(completed: false));
  }

  void _finish({required bool completed}) {
    _outcome = SessionOutcome(
        attempts: List.unmodifiable(_attempts), completed: completed);
    _notify();
  }

  void _add(SessionEntry e) {
    _transcript.add(e);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Invariant: nothing fires after dispose — no scheduler callback runs,
  /// no notifyListeners. This replaces the old per-timer mounted-guards.
  @override
  void dispose() {
    _disposed = true;
    _scheduler.cancelAll();
    super.dispose();
  }
}

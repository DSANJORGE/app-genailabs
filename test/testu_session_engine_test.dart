import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_session_engine.dart';

/// Second adapter at the SessionScheduler seam: collects callbacks, the test
/// decides when time passes.
class FakeScheduler implements SessionScheduler {
  final pending = <void Function()>[];

  @override
  void after(Duration d, void Function() fn) => pending.add(fn);

  @override
  void cancelAll() => pending.clear();

  void flush() {
    while (pending.isNotEmpty) {
      pending.removeAt(0)();
    }
  }
}

const qs = [
  SessionQuestion(okIdx: 1),
  SessionQuestion(okIdx: 1, video: true),
  SessionQuestion(okIdx: 2),
];

SessionController make(FakeScheduler sched, {bool confAcked = true}) =>
    SessionController(
        questions: () => qs, scheduler: sched, confAcked: confAcked);

void main() {
  test('judge is a pure verdict', () {
    const q = SessionQuestion(okIdx: 2);
    final right =
        judge(q, qi: 0, chosen: 2, confidence: 3, assisted: false);
    final wrong = judge(q, qi: 0, chosen: 1, confidence: 0, assisted: true);
    expect(right.correct, isTrue);
    expect(wrong.correct, isFalse);
    expect(wrong.assisted, isTrue);
  });

  test('full session: framing → prompt → verdict → offer → … → outcome', () {
    final sched = FakeScheduler();
    final c = make(sched);

    c.start();
    sched.flush(); // opener + framing→prompt
    expect(c.transcript, [isA<Framing>(), isA<Prompt>()]);
    expect(c.progress, closeTo(0.08, 1e-9));

    expect(c.submit(chosen: 1, confidence: 3), HapticIntent.medium);
    sched.flush();
    expect(c.transcript.last, isA<ContinueOffer>());
    expect((c.transcript.last as ContinueOffer).last, isFalse);

    c.continueSession(); // → video question: no timer to prompt
    expect((c.transcript.last as Framing).video, isTrue);
    expect(sched.pending, isEmpty);
    c.watchedVideo();
    expect(c.transcript.last, isA<Prompt>());

    expect(c.submit(chosen: 0, confidence: 1), HapticIntent.heavy);
    sched.flush();
    c.continueSession();
    sched.flush(); // framing→prompt of q3
    expect(c.submit(chosen: 2, confidence: 2), HapticIntent.medium);
    sched.flush();
    expect((c.transcript.last as ContinueOffer).last, isTrue);

    expect(c.outcome, isNull);
    c.continueSession();
    expect(c.progress, 1.0);
    sched.flush(); // complete → debrief delay
    final o = c.outcome!;
    expect(o.completed, isTrue);
    expect(o.attempts.map((a) => a.correct), [true, false, true]);
    c.dispose();
  });

  test('conf-ack gate swallows submit until acknowledged', () {
    final sched = FakeScheduler();
    final c = make(sched, confAcked: false);
    c.start();
    sched.flush();
    expect(c.needsConfAck, isTrue);
    expect(c.submit(chosen: 1, confidence: 2), isNull); // swallowed
    expect(c.transcript.whereType<Verdict>(), isEmpty);
    c.acknowledgeConf();
    expect(c.needsConfAck, isFalse);
    expect(c.submit(chosen: 1, confidence: 2), HapticIntent.medium);
    c.dispose();
  });

  test('hint marks the attempt assisted and adds a note', () {
    final sched = FakeScheduler();
    final c = make(sched);
    c.start();
    sched.flush();
    c.markHintUsed();
    expect(c.transcript.last, isA<HintNote>());
    c.submit(chosen: 0, confidence: 0);
    final a = (c.transcript.last as Verdict).attempt;
    expect(a.assisted, isTrue);
    c.dispose();
  });

  test('stop flow: challenge, then farewell and a partial outcome', () {
    final sched = FakeScheduler();
    final c = make(sched);
    c.start();
    sched.flush();
    c.submit(chosen: 1, confidence: 3);
    sched.flush();
    c.requestStop();
    expect((c.transcript.last as StopChallenge).remaining, 2);
    c.confirmStop();
    expect(c.transcript.last, isA<StopFarewell>());
    sched.flush();
    expect(c.outcome!.completed, isFalse);
    expect(c.outcome!.attempts, hasLength(1));
    c.dispose();
  });

  test('keep-going from the stop challenge advances the session', () {
    final sched = FakeScheduler();
    final c = make(sched);
    c.start();
    sched.flush();
    c.submit(chosen: 0, confidence: 0);
    sched.flush();
    c.requestStop();
    c.continueSession();
    expect(c.transcript.last, isA<Framing>());
    expect(c.outcome, isNull);
    c.dispose();
  });

  test('illegal mutators are silent no-ops', () {
    final sched = FakeScheduler();
    final c = make(sched);
    c.start();
    expect(c.submit(chosen: 0, confidence: 0), isNull); // still opening
    sched.flush();
    final len = c.transcript.length;
    c.continueSession(); // not offered
    c.watchedVideo(); // q1 is not a video question
    c.requestStop(); // not offered
    c.confirmStop(); // not challenged
    expect(c.transcript.length, len);
    c.submit(chosen: 1, confidence: 3);
    expect(c.submit(chosen: 1, confidence: 3), isNull); // double-tap
    expect(c.transcript.whereType<Verdict>(), hasLength(1));
    c.dispose();
  });

  test('out-of-range arguments throw', () {
    final sched = FakeScheduler();
    final c = make(sched);
    c.start();
    sched.flush();
    expect(() => c.submit(chosen: -1, confidence: 0), throwsArgumentError);
    expect(() => c.submit(chosen: 0, confidence: 4), throwsArgumentError);
    c.dispose();
  });

  test('nothing fires after dispose', () {
    final sched = FakeScheduler();
    final c = make(sched);
    c.start();
    sched.flush();
    c.submit(chosen: 1, confidence: 3); // schedules verdict→offer
    expect(sched.pending, isNotEmpty);
    var notified = false;
    c.addListener(() => notified = true);
    c.dispose();
    expect(sched.pending, isEmpty);
    expect(notified, isFalse);
  });
}

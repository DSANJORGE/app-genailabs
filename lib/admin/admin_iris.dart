import 'dart:async';

import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_md.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_api.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_reading.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// One entry of the Iris thread: a question the manager asked, an answer, or
/// the "not available" notice standing in for an answer that never came.
///
/// A failed turn stays on screen (the thread survives the failure) but never
/// rides along as history — the model must not be told it once said nothing.
class IrisTurn {
  IrisTurn.you(this.text)
      : reply = null,
        failed = false;
  IrisTurn.iris(AskReply this.reply)
      : text = '',
        failed = false;
  IrisTurn.down()
      : text = '',
        reply = null,
        failed = true;

  final String text;
  final AskReply? reply;
  final bool failed;
}

/// The Iris conversation, owned by the shell rather than the panel.
///
/// A question takes 5-15 s and a manager can close the panel — or leave the
/// analytics screens entirely — in the middle of one. Keeping the turns AND
/// the in-flight state out here means the answer still lands: reopening the
/// panel shows the dots, then the reply, instead of an orphaned question with
/// no answer and no way to retry.
class IrisThread extends ChangeNotifier {
  final turns = <IrisTurn>[];

  /// One question in flight per user; the composer is inert meanwhile.
  bool busy = false;

  /// Guards a reply that lands after [retry] moved the thread on.
  int _request = 0;

  /// The last six live turns as `{role, text}` — the only conversation the
  /// server ever sees, and it is built before the new question joins it. A
  /// failed turn is never sent: the model must not be told it said nothing.
  List<Map<String, String>> _history() {
    final live = [for (final t in turns) if (!t.failed) t];
    return [
      for (final t in live.skip(live.length <= 6 ? 0 : live.length - 6))
        {
          'role': t.reply == null ? 'user' : 'assistant',
          'text': t.reply?.answer ?? t.text,
        },
    ];
  }

  Future<void> ask(
    AdminApi api, {
    required String question,
    required String screen,
    String? user,
    Map<String, String> q = const {},
  }) async {
    if (busy) return;
    final history = _history();
    final mine = ++_request;
    turns.add(IrisTurn.you(question));
    busy = true;
    notifyListeners();
    IrisTurn landed;
    try {
      landed = IrisTurn.iris(await api.ask(
        question: question,
        screen: screen,
        user: user,
        history: history,
        q: q,
      ));
    } catch (_) {
      // Every failure is the same failure to a reader: the tutor is not
      // answering. AdminApi.ask has already folded 503 and `ok:false` into
      // AskUnavailable, and the console data is untouched either way.
      landed = IrisTurn.down();
    }
    if (mine != _request) return;
    turns.add(landed);
    busy = false;
    notifyListeners();
  }

  /// Retry drops the failed turn AND the question above it, then asks again —
  /// so a recovered server leaves one clean exchange, not three entries.
  void retry(
    AdminApi api,
    int index, {
    required String screen,
    String? user,
    Map<String, String> q = const {},
  }) {
    // Before the removal, not after: a busy thread must lose nothing.
    if (busy || index == 0) return;
    final question = turns[index - 1].text;
    if (question.isEmpty) return;
    turns.removeRange(index - 1, index + 1);
    ask(api, question: question, screen: screen, user: user, q: q);
  }
}

/// The org's tutor as the console's analyst (spec analytics-v1 §6.7): a
/// 360 px right-side panel that answers from the server-built fact sheet and
/// cites every figure back to the view it was measured in.
///
/// The panel owns the conversation, never the data: it asks `ask.json`, and a
/// citation tap is a filter change plus a [ConsoleNav.go] — exactly what the
/// user could have done by hand, which is why the answer is checkable.
class IrisPanel extends StatefulWidget {
  const IrisPanel({
    super.key,
    required this.api,
    required this.nav,
    required this.filters,
    required this.persona,
    required this.screen,
    required this.thread,
    required this.onClose,
    this.selectedUser,
  });

  final AdminApi api;
  final ConsoleNav nav;
  final AnalyticsFilters filters;

  /// Name and avatar of the site's tutor; null on a server that predates the
  /// `persona` key, which is why the name falls back to [personaNameOf].
  final AdminPersona? persona;

  /// The section the manager is looking at — it picks the suggestions and
  /// tells the server which screen the question is about.
  final String screen;

  /// The person on screen, when the section is a person drill-down: the
  /// server adds that person's own facts to the sheet.
  final String? selectedUser;

  /// Owned by the shell, so one conversation follows the user across screens
  /// and survives closing the panel mid-question.
  final IrisThread thread;

  final VoidCallback onClose;

  @override
  State<IrisPanel> createState() => _IrisPanelState();
}

class _IrisPanelState extends State<IrisPanel> {
  /// Turns whose "see the data used" list is open, by identity — the thread
  /// only ever grows, but identity survives a retry that removes two entries.
  final _open = <IrisTurn>{};

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.thread.addListener(_onThread);
  }

  @override
  void dispose() {
    widget.thread.removeListener(_onThread);
    _scroll.dispose();
    super.dispose();
  }

  void _onThread() {
    if (mounted) setState(_toBottom);
  }

  String get _name => personaNameOf(widget.persona);

  List<IrisTurn> get _thread => widget.thread.turns;

  bool get _busy => widget.thread.busy;

  // ------------------------------------------------------------------- ask

  void _ask(String question) => widget.thread.ask(
        widget.api,
        question: question,
        screen: widget.screen,
        user: widget.selectedUser,
        q: widget.filters.query,
      );

  void _retry(int index) => widget.thread.retry(
        widget.api,
        index,
        screen: widget.screen,
        user: widget.selectedUser,
        q: widget.filters.query,
      );

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  // -------------------------------------------------------------- citation

  /// A citation is a place, not a footnote: put the console on the window the
  /// fact was measured in, then open the view and pulse the element.
  void _openCitation(Citation c) {
    final f = c.filters;
    widget.filters.set(
      period: _periodOf(f['period']),
      topic: _some(f['entitytopic']),
      team: _some(f['team']),
    );
    widget.nav.go(
      c.view,
      // Only the two drill-downs take an entity; putting one on `overview`
      // would write an id into the URL that no screen there reads.
      entityId: switch (c.view) {
        'person' => _some(f['user']),
        'team' => _some(f['team']),
        _ => null,
      },
      // Fact ids are opaque, so `focus` is what a screen can match on; the id
      // is the fallback for a server that predates the key.
      highlight: c.focus.isNotEmpty ? c.focus : c.id,
    );
  }

  static String? _some(String? v) => (v ?? '').isEmpty ? null : v;

  /// `period` is a console shorthand the server echoes back when the caller
  /// sent one. Absent or unknown means "leave the window alone".
  static Period? _periodOf(String? name) {
    for (final p in Period.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  // ------------------------------------------------------------------ copy

  /// Three to five openers per screen, so the first question is never a blank
  /// page. Person deliberately says "this person" rather than a name: the
  /// panel is handed the id, and the server already put that person's facts
  /// on the sheet.
  List<String> get _suggestions => switch (widget.screen) {
        'activity' => [
            L('Who has not been in for over 7 days?',
                '¿Quién lleva más de 7 días sin entrar?'),
            L('When do people learn?', '¿Cuándo aprende la gente?'),
            L('What do people ask $_name about?',
                '¿Sobre qué preguntan a $_name?'),
          ],
        'mastery' => [
            L('Which subtopic is the weakest?',
                '¿Qué subtema es el más débil?'),
            L('Who has misconceptions?', '¿Quién tiene conceptos erróneos?'),
          ],
        'person' => [
            L('What should this person focus on?',
                '¿En qué debería centrarse esta persona?'),
            L('Any misconceptions?', '¿Tiene conceptos erróneos?'),
          ],
        'team' => [
            L('How is this team doing against the organisation?',
                '¿Cómo va este equipo frente a la organización?'),
          ],
        _ => [
            L('Who needs help this week?',
                '¿Quién necesita ayuda esta semana?'),
            L('Which subtopic is the weakest?',
                '¿Qué subtema es el más débil?'),
            L('Compare the teams', 'Compara los equipos'),
          ],
      };

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(t),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            children: [
              Text(
                L('$_name only uses the data you can see in this console, and '
                    'cites where it comes from.',
                    '$_name solo usa los datos que tú puedes ver en esta '
                    'consola y cita de dónde salen.'),
                style: kNote,
              ),
              const SizedBox(height: 14),
              if (_thread.isEmpty) _opener(),
              for (final (i, turn) in _thread.indexed) _turn(i, turn),
              if (_busy) ...[
                TestuEyebrow(_name.toUpperCase(),
                    letterSpacing: AdminTokens.eyebrowTracking),
                const SizedBox(height: 8),
                const _Dots(),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: TestuComposer(
            hint: L('Ask $_name…', 'Pregunta a $_name…'),
            // Facade mode is how this composer says "not now": the field goes
            // inert rather than accepting a question nobody is listening to.
            onTap: _busy ? () {} : null,
            onSend: _ask,
          ),
        ),
      ],
    );
  }

  Widget _header(TestuTokens t) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.line)),
        ),
        child: Row(
          children: [
            PersonaAvatar(url: widget.persona?.avatar),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Running copy, so `mut` rather than kNote's `faint`
                  // (3.7:1 on card). The privacy line below keeps kNote: it
                  // is one pinned sentence, read once.
                  Text(_subtitle, style: AdminTokens.footnote, maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConsoleIconButton(
              glyph: '✕',
              label: L('Close', 'Cerrar'),
              onTap: widget.onClose,
            ),
          ],
        ),
      );

  String get _subtitle {
    final org = widget.persona?.organization ?? '';
    return org.isEmpty
        ? L('Reads this console', 'Analiza esta consola')
        : L('Tutor of $org · reads this console',
            'Tutora de $org · analiza esta consola');
  }

  /// The empty thread: one line of what to ask, and this screen's openers.
  Widget _opener() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow(_name.toUpperCase(),
              letterSpacing: AdminTokens.eyebrowTracking),
          const SizedBox(height: 6),
          Text(
            L('Ask me about activity, mastery or one person.',
                'Pregúntame por la actividad, el dominio o una persona.'),
            style: _bodyStyle,
          ),
          const SizedBox(height: 10),
          _chips(_suggestions),
        ],
      );

  Widget _turn(int index, IrisTurn turn) {
    if (turn.reply == null && !turn.failed) return TestuYouMsg(text: turn.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow(_name.toUpperCase(),
              letterSpacing: AdminTokens.eyebrowTracking),
          const SizedBox(height: 6),
          if (turn.failed) ...[
            Text(
              L('$_name is not available right now.',
                  '$_name no está disponible ahora. Los datos de la consola '
                  'siguen aquí.'),
              style: _bodyStyle.copyWith(color: AdminTokens.redText),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TestuAct(L('Retry', 'Reintentar'),
                  onTap: () => _retry(index)),
            ),
          ] else
            ..._answer(turn),
        ],
      ),
    );
  }

  List<Widget> _answer(IrisTurn turn) {
    final r = turn.reply!;
    final showFacts = _open.contains(turn);
    return [
      Text.rich(TextSpan(children: _answerSpans(r)), style: _bodyStyle),
      if (r.citations.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, c) in r.citations.indexed)
              CitationChip(index: i + 1, citation: c, onTap: () => _openCitation(c)),
          ],
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(
                () => showFacts ? _open.remove(turn) : _open.add(turn)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              showFacts
                  ? L('Hide the data used', 'Ocultar los datos usados')
                  : L('See the data used', 'Ver los datos usados'),
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 10.5,
                  color: TestuTokens.instance.blue),
            ),
          ),
        ),
        if (showFacts) _facts(r),
      ],
      if (r.followups.isNotEmpty) ...[
        const SizedBox(height: 8),
        _chips(r.followups),
      ],
    ];
  }

  /// The cited facts in full, label beside value — the answer's own working,
  /// so a manager can check a figure without leaving the panel.
  Widget _facts(AskReply r) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final c in r.citations)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(c.label, style: AdminTokens.footnote),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(c.value,
                        style: AdminTokens.footnote.copyWith(color: t.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chips(List<String> labels) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final q in labels) ConsoleChip(q, onTap: () => _ask(q)),
        ],
      );

  static final _bodyStyle = TextStyle(
    fontFamily: 'Geist',
    fontSize: 12.5,
    height: 1.62,
    color: TestuTokens.instance.ink,
  );
}

/// The answer with every `[fN]` marker swapped for the citation's number, in
/// `focus`. A marker the reply never listed disappears rather than printing a
/// fact id at a reader — the server strips unknown ids, this strips unlisted
/// ones.
List<InlineSpan> _answerSpans(AskReply reply) {
  final number = {
    for (final (i, c) in reply.citations.indexed) c.id: i + 1,
  };
  // Substitute first, parse once. Handing mdSpans one fragment per marker
  // would cut `**bold**` runs in half and let a fragment starting " * Marta"
  // be read as a bullet; a sentinel no markdown syntax can contain survives
  // the parse and is split out of the finished spans instead.
  const sentinel = '\u0000';
  final marks = <int>[];
  final text = reply.answer.replaceAllMapped(RegExp(r' ?\[(f\d+)\]'), (m) {
    final n = number[m[1]];
    if (n == null) return '';
    marks.add(n);
    return sentinel;
  });

  final out = <InlineSpan>[];
  var next = 0;
  for (final span in mdSpans(text)) {
    final body = span is TextSpan ? (span.text ?? '') : '';
    if (!body.contains(sentinel)) {
      out.add(span);
      continue;
    }
    for (final (i, part) in body.split(sentinel).indexed) {
      if (i > 0 && next < marks.length) {
        out.add(TextSpan(
          text: ' [${marks[next++]}]',
          style: TextStyle(
              color: AdminTokens.focus, fontWeight: FontWeight.w600),
        ));
      }
      if (part.isNotEmpty) {
        out.add(TextSpan(text: part, style: (span as TextSpan).style));
      }
    }
  }
  return out;
}

/// The app's typing dots: three dots, one lit at a time, 850 ms round. Under
/// `MediaQuery.disableAnimations` they hold still — the panel still says it is
/// working, it just stops moving.
class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> {
  Timer? _timer;
  int _lit = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = AdminTokens.dur(context, 850) == Duration.zero
        ? null
        : Timer.periodic(const Duration(milliseconds: 283),
            (_) => setState(() => _lit = (_lit + 1) % 3));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Semantics(
      label: L('Thinking', 'Pensando'),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: AnimatedOpacity(
                opacity: _timer == null || i == _lit ? 1 : 0.3,
                duration: AdminTokens.dur(context, 283),
                curve: TestuTokens.curve,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: t.mut, shape: BoxShape.circle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

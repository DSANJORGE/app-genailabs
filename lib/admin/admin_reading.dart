import '../testu/testu_i18n.dart';
import 'admin_models.dart';

/// The sentences the tutor opens every analytics screen with (spec
/// analytics-v1 §6), as pure functions over the parsed reply: no
/// BuildContext, no widgets, no formatting beyond the words themselves. That
/// is what makes a rule testable — and a rule that cannot be tested is a
/// rule nobody trusts.
///
/// Every screen composes at most three sentences, in priority order, and
/// drops the ones with nothing to say. A rule never invents a comparison the
/// server did not send: a missing `previous` key means the sentence simply
/// stops after the count.
///
/// What is period-scoped and what is not matters here. `cohort.*` and the
/// daily `series` are the selected window; `levels`, `topics[].levels`,
/// `calibration` and `median` are CUMULATIVE, so no sentence built from them
/// may say "in the period".

String _people(int n) => n == 1 ? L('person', 'persona') : L('people', 'personas');

/// Percent in the console's own spacing: Spanish separates the sign, English
/// does not.
String pct(double share) {
  final n = (share * 100).round();
  return L('$n%', '$n %');
}

/// The comparison line under a [StatBlock] — signed, because the number
/// above it is the value and this is only its direction. [week] words it
/// against last week (a 7-day stat); otherwise against the selected period.
String deltaLine(int delta, {bool week = false}) {
  if (delta == 0) {
    return week
        ? L('same as last week', 'igual que la semana pasada')
        : L('same as the previous period', 'igual que el periodo anterior');
  }
  // U+2212 MINUS, not a hyphen: this sits next to mono figures.
  final n = '${delta > 0 ? '+' : '−'}${delta.abs()}';
  return week
      ? L('$n vs last week', '$n que la semana pasada')
      : L('$n vs the previous period', '$n que el periodo anterior');
}

/// The reading's own delta wording — unsigned and spelled out, because it is
/// prose rather than a label.
String _weekDelta(int delta) => switch (delta) {
      0 => L('same as the week before', 'igual que la anterior'),
      > 0 => L('$delta more than the week before', '$delta más que la anterior'),
      _ => L('${-delta} fewer than the week before', '${-delta} menos que la anterior'),
    };

/// What the console calls the `id: ""` bucket in `overview.teams[]` — the
/// learners nobody has put in a team yet. It is a real row with real
/// numbers, so it is named rather than filtered out.
String teamName(TeamStat t) =>
    t.id.isEmpty || t.name.isEmpty ? L('No team', 'Sin equipo') : t.name;

/// Resumen (§6.1): activity, then the weakest subtopic, then misconceptions.
List<String> overviewReading(Overview o) {
  final c = o.cohort;
  // Nobody has answered: one sentence that teaches when data appears, and
  // none of the rules below, which would all read as zeros.
  if (c.activated == 0) {
    return [
      L('Nobody has answered yet. Data appears 15 minutes after the first session.',
          'Nadie ha respondido todavía. Los datos aparecen 15 minutos después de la primera sesión.'),
    ];
  }

  final out = <String>[];

  final head = L(
    '${c.active7d} of ${c.total} ${_people(c.total)} active this week',
    '${c.active7d} de ${c.total} '
        '${c.total == 1 ? 'persona activa' : 'personas activas'} esta semana',
  );
  final before = o.previous['active7d'];
  out.add(before == null ? '$head.' : '$head, ${_weekDelta(c.active7d - before)}.');

  // The weakest subtopic anywhere in the current filter: the topic whose
  // weakest section has the most beginners. `weakest` may be null on any
  // topic, and every topic may lack one.
  TopicStat? worst;
  for (final t in o.topics) {
    if (t.weakest == null) continue;
    if (worst == null || t.weakest!.beginners > worst.weakest!.beginners) worst = t;
  }
  if (worst != null && worst.weakest!.beginners > 0) {
    final w = worst.weakest!;
    out.add(L(
      'In ${worst.name} the weakest subtopic is “${w.name}”: '
          'Beginner for ${w.beginners} ${_people(w.beginners)}.',
      'En ${worst.name} el subtema más débil es «${w.name}»: '
          'Principiante en ${w.beginners} ${_people(w.beginners)}.',
    ));
  }

  // Misconceptions are summed off the daily series, not off `calibration`,
  // which is cumulative — this sentence says "in the period" and has to mean it.
  final wrong = o.series.fold<int>(0, (a, d) => a + d.certainwrong);
  if (wrong > 0) {
    out.add(L(
      '$wrong confident but wrong ${wrong == 1 ? 'answer' : 'answers'} in the period: '
          'misconceptions, the finding that matters most.',
      '$wrong ${wrong == 1 ? 'respuesta segura y errónea' : 'respuestas seguras y erróneas'} '
          'en el periodo: concepto erróneo, el hallazgo que más importa.',
    ));
  }

  return out.take(3).toList();
}

/// Actividad (§6.2): adoption first — how many got in, how many started.
List<String> activityReading(Activity a, Cohort c) {
  final total = a.funnel['cohort'] ?? c.total;
  final signedin = a.funnel['signedin'] ?? 0;
  final answered = a.funnel['answered'] ?? c.activated;

  final out = <String>[
    L(
      '$signedin of $total ${_people(total)} have opened the app; '
          '$answered have answered at least one question.',
      '$signedin de $total ${_people(total)} han entrado en la app; '
          '$answered han respondido al menos una pregunta.',
    ),
  ];

  final idle = a.inactive.length;
  if (idle > 0) {
    out.add(L(
      '$idle ${_people(idle)} ${idle == 1 ? 'has' : 'have'} gone more than 7 days '
          'without activity.',
      '$idle ${_people(idle)} ${idle == 1 ? 'lleva' : 'llevan'} más de 7 días '
          'sin actividad.',
    ));
  }
  return out.take(3).toList();
}

/// Dominio (§6.3): the weakest topic, counted in people rather than rows,
/// then the subtopic the whole cohort is weakest at.
///
/// Levels are per person: a learner is one Beginner in a topic no matter how
/// many sections they answered there, which is why both rules aggregate
/// user x topic and user x section before they count anything.
List<String> masteryReading(AdminReport r) {
  if (r.rows.every((row) => row.answered == 0)) {
    return [
      L('Nobody has answered anything yet, so there is no mastery to read.',
          'Nadie ha respondido todavía, así que aún no hay dominio que leer.'),
    ];
  }

  // topic -> user -> (mastered, answered), and the same per subtopic.
  final byTopic = <String, Map<String, List<int>>>{};
  final bySection = <String, Map<String, List<int>>>{};
  final topicName = <String, String>{};
  final sectionName = <String, String>{};
  for (final row in r.rows) {
    topicName[row.topicId] = row.topic;
    sectionName[row.sectionKey] = _section(row);
    for (final (map, key) in [(byTopic, row.topicId), (bySection, row.sectionKey)]) {
      final tally = map.putIfAbsent(key, () => {}).putIfAbsent(row.user, () => [0, 0]);
      tally[0] += row.mastered;
      tally[1] += row.answered;
    }
  }

  /// People at Beginner in [key] — the count both sentences are ranked on.
  int beginners(Map<String, Map<String, List<int>>> map, String key) => map[key]!
      .values
      .where((t) => levelOf(t[0], t[1]) == 'beginner')
      .length;

  String? worstTopic;
  var worstCount = 0;
  for (final key in byTopic.keys) {
    final n = beginners(byTopic, key);
    // Ties keep the first topic seen: the server's own order, not a coin toss.
    if (n > worstCount) {
      worstCount = n;
      worstTopic = key;
    }
  }
  if (worstTopic == null) {
    return [
      L('Nobody is at Beginner in any topic.',
          'Nadie está en Principiante en ningún tema.'),
    ];
  }

  final out = <String>[
    L(
      '${topicName[worstTopic]} is the weakest topic: $worstCount '
          '${_people(worstCount)} at Beginner.',
      '${topicName[worstTopic]} es el tema más flojo: $worstCount '
          '${_people(worstCount)} en Principiante.',
    ),
  ];

  final worstSection = weakestSubtopic(r.rows);
  if (worstSection != null) {
    out.add(L(
      '\u201C${sectionName[worstSection]}\u201D is the cohort\u2019s weakest subtopic.',
      '\u00AB${sectionName[worstSection]}\u00BB es el subtema m\u00E1s d\u00E9bil de la cohorte.',
    ));
  }
  return out;
}

/// The subtopic the cohort is weakest at: the one where the most PEOPLE are
/// at Beginner, returned as [MasteryRow.sectionKey].
///
/// Ties break on the lowest `"<topic> <section title>"` — the order the
/// Dominio grid lays its columns out in — so the sentence this feeds and the
/// column the summary strip underlines can never name different subtopics.
String? weakestSubtopic(List<MasteryRow> rows) {
  final tallies = <String, Map<String, List<int>>>{};
  final order = <String, String>{};
  for (final r in rows) {
    order[r.sectionKey] = '${r.topic} ${r.section}';
    final t = tallies
        .putIfAbsent(r.sectionKey, () => {})
        .putIfAbsent(r.user, () => [0, 0]);
    t[0] += r.mastered;
    t[1] += r.answered;
  }
  String? worst;
  var count = 0;
  final keys = tallies.keys.toList()
    ..sort((a, b) => order[a]!.compareTo(order[b]!));
  for (final k in keys) {
    final n = tallies[k]!
        .values
        .where((t) => levelOf(t[0], t[1]) == 'beginner')
        .length;
    if (n > count) {
      count = n;
      worst = k;
    }
  }
  return worst;
}

/// Equipo (§6.5): the team's active share, against the organisation median
/// when the server sent one (it withholds it under 5 learners).
List<String> teamReading(TeamStat t, Overview o) {
  final share = t.members == 0 ? 0.0 : t.active7d / t.members;
  final out = <String>[
    L(
      '${teamName(t)}: ${t.active7d} of ${t.members} ${_people(t.members)} '
          'active this week, ${pct(share)}.',
      '${teamName(t)}: ${t.active7d} de ${t.members} '
          '${t.members == 1 ? 'persona activa' : 'personas activas'} '
          'esta semana, ${pct(share)}.',
    ),
  ];

  final median = o.median?.activeShare;
  if (median != null) {
    // Compared on the rounded figures the reader can see, so the sentence
    // never says "above" next to two identical percentages.
    final mine = (share * 100).round();
    final org = (median * 100).round();
    out.add(switch (mine - org) {
      0 => L('That matches the organisation median of ${pct(median)}.',
          'Coincide con la mediana de la organización, ${pct(median)}.'),
      > 0 => L('That is above the organisation median of ${pct(median)}.',
          'Está por encima de la mediana de la organización, ${pct(median)}.'),
      _ => L('That is below the organisation median of ${pct(median)}.',
          'Está por debajo de la mediana de la organización, ${pct(median)}.'),
    });
  }

  final weak = t.weakest;
  if (weak != null && weak.isNotEmpty) {
    out.add(L('The weakest topic is $weak.', 'El tema más débil es $weak.'));
  }
  return out.take(3).toList();
}

/// Persona (§6.4), on the app's own tutor-greeting rule
/// (`testu_tutor.dart:_liveGreeting`): the last section the learner worked
/// on with its score, then the section they are weakest in.
List<String> personReading(PersonReport p) {
  final who = p.user.firstName.isEmpty ? p.user.name : p.user.firstName;
  final answered = [for (final r in p.rows) if (r.answered > 0) r];
  if (answered.isEmpty) {
    return [
      L('$who has not answered anything yet.', '$who todavía no ha respondido nada.'),
    ];
  }

  MasteryRow? latest;
  for (final r in answered) {
    final at = r.lastActivity;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest.lastActivity!)) latest = r;
  }
  // Rows without a timestamp still deserve a sentence: fall back to the
  // first, which is the server's own order.
  final last = latest ?? answered.first;

  var weakest = answered.first;
  for (final r in answered) {
    if (r.mastered / r.answered < weakest.mastered / weakest.answered) weakest = r;
  }

  final out = <String>[
    L(
      'The last thing $who worked on was “${_section(last)}”: '
          '${last.mastered} of ${last.answered} right.',
      'Lo último que $who trabajó fue «${_section(last)}»: '
          '${last.mastered} de ${last.answered} bien.',
    ),
  ];
  if (weakest.section != last.section) {
    out.add(L(
      'Where $who is weakest is “${_section(weakest)}”: '
          '${weakest.mastered} of ${weakest.answered} right.',
      'Donde $who más flojea es «${_section(weakest)}»: '
          '${weakest.mastered} de ${weakest.answered} bien.',
    ));
  }
  return out.take(3).toList();
}

/// Section titles arrive numbered ("2. Debida diligencia"); prose reads them
/// bare — the same strip the app's tutor greeting does.
String _section(MasteryRow r) => r.section.replaceFirst(RegExp(r'^\d+\.\s*'), '');

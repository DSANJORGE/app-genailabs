import 'package:flutter/painting.dart';

/// Tutor markdown as spans: `**bold**`, `*italic*`, `` `code` ``, `#`
/// headings (bold lines), `*`/`-` bullets ("•"). ponytail: no tables,
/// links or nesting — a markdown package when a reply needs them.
///
/// Its own leaf file so the console can render a tutor reply without
/// importing `testu_sully.dart`, which drags the whole learner session
/// (sockets, video player, PDF viewer) in behind it.
List<InlineSpan> mdSpans(String md) {
  final out = <InlineSpan>[];
  final lines = md.split('\n');
  for (final (i, raw) in lines.indexed) {
    var line = raw;
    final h = RegExp(r'^\s*#{1,6}\s+(.*)$').firstMatch(line);
    if (h != null) line = '**${h[1]}**';
    line = line.replaceFirst(RegExp(r'^\s*[*\-•]\s+'), '• ');
    var last = 0;
    for (final m in _mdInline.allMatches(line)) {
      if (m.start > last) out.add(TextSpan(text: line.substring(last, m.start)));
      out.add(TextSpan(
        text: m[1] ?? m[2] ?? m[3] ?? m[4] ?? m[5],
        style: m[1] != null || m[2] != null
            ? const TextStyle(fontWeight: FontWeight.w700)
            : m[5] != null
                ? const TextStyle(fontFamily: 'GeistMono')
                : const TextStyle(fontStyle: FontStyle.italic),
      ));
      last = m.end;
    }
    if (last < line.length) out.add(TextSpan(text: line.substring(last)));
    if (i < lines.length - 1) out.add(const TextSpan(text: '\n'));
  }
  return out;
}

final _mdInline = RegExp(
    r'\*\*(.+?)\*\*|__(.+?)__|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])|(?<!\w)_(.+?)_(?!\w)|`(.+?)`');

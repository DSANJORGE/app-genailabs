import 'dart:convert';

class CsvRow {
  CsvRow(this.email, this.firstName, this.lastName, this.team, this.error);
  final String email, firstName, lastName, team;
  final String? error;
}

class CsvImport {
  CsvImport(this.rows);
  final List<CsvRow> rows;
  List<CsvRow> get valid => [for (final r in rows) if (r.error == null) r];

  List<int> toCsvBytes() => utf8.encode(
      'id,email,firstName,lastName,team\r\n${[for (final r in valid) csvOf([[r.email, r.email, r.firstName, r.lastName, r.team]])].join()}');
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const _required = ['email', 'firstName', 'lastName', 'team'];

/// ponytail: split on commas; fields with embedded commas need quotes,
/// handled by _split. Good enough for HR exports.
CsvImport parseUsersCsv(String text, {required Set<String> teamIds, required Set<String> existingEmails}) {
  final lines = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return CsvImport([]);
  final header = _split(lines.first).map((h) => h.trim()).toList();
  final missing = [for (final c in _required) if (!header.contains(c)) c];
  final seen = <String>{};
  final rows = <CsvRow>[];
  for (final line in lines.skip(1)) {
    final cells = _split(line);
    String cell(String c) {
      final i = header.indexOf(c);
      return i < 0 || i >= cells.length ? '' : cells[i].trim();
    }

    final email = cell('email').toLowerCase();
    final team = cell('team').toLowerCase();
    String? error;
    if (missing.isNotEmpty) {
      error = 'Faltan columnas: ${missing.join(', ')}';
    } else if (!_email.hasMatch(email)) {
      error = 'Correo inválido';
    } else if (!teamIds.contains(team)) {
      error = 'Equipo desconocido: $team';
    } else if (!seen.add(email)) {
      error = 'Correo repetido en el archivo';
    } else if (existingEmails.contains(email)) {
      error = 'Ya existe';
    }
    rows.add(CsvRow(email, cell('firstName'), cell('lastName'), team, error));
  }
  return CsvImport(rows);
}

List<String> _split(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var q = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (q) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          q = false;
        }
      } else {
        b.write(c);
      }
    } else if (c == '"') {
      q = true;
    } else if (c == ',') {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(c);
    }
  }
  out.add(b.toString());
  return out;
}

String csvOf(List<List<String>> table) => [
      for (final row in table)
        '${row.map((v) => v.contains(RegExp(r'[",\r\n]')) ? '"${v.replaceAll('"', '""')}"' : v).join(',')}\r\n'
    ].join();

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_csv.dart';

void main() {
  const teams = {'norte', 'sur'};
  test('valid rows pass, bad email / unknown team / duplicate / existing are flagged', () {
    final r = parseUsersCsv('email,firstName,lastName,team\nAna@x.com,Ana,Pé,norte\nmalo,Bo,B,norte\nc@x.com,C,C,oeste\nana@x.com,Ana,Dup,sur\nold@x.com,O,O,sur\n',
        teamIds: teams, existingEmails: {'old@x.com'});
    expect(r.rows.length, 5);
    expect(r.valid.map((x) => x.email), ['ana@x.com']);
    expect(r.rows[1].error, isNotNull); expect(r.rows[2].error, isNotNull); expect(r.rows[3].error, isNotNull); expect(r.rows[4].error, isNotNull);
  });
  test('export csv has id = lowercase email and only valid rows', () {
    final r = parseUsersCsv('email,firstName,lastName,team\nA@x.com,A,A,norte\nbad,B,B,norte\n', teamIds: teams, existingEmails: {});
    expect(utf8.decode(r.toCsvBytes()), 'id,email,firstName,lastName,team\r\na@x.com,a@x.com,A,A,norte\r\n');
  });
  test('missing header column is an error for every row', () {
    final r = parseUsersCsv('email,firstName\na@x.com,A\n', teamIds: teams, existingEmails: {});
    expect(r.valid, isEmpty); expect(r.rows.single.error, contains('lastName'));
  });
  test('csvOf quotes commas and quotes', () {
    expect(csvOf([['a', 'b,c', 'd"e']]), 'a,"b,c","d""e"\r\n');
  });
  test('csvOf guards formula-injection leading chars', () {
    expect(csvOf([['=cmd', '+1', '-1', '@x', 'ok']]), "'=cmd,'+1,'-1,'@x,ok\r\n");
  });
}

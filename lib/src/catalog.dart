import 'dart:convert';

typedef Entry = ({String source, String target, bool fuzzy});

/// Gettext catalog whose entries are keyed by `msgctxt`.
///
/// Comments, obsolete entries and plural forms are discarded: the game has no
/// use for them and Weblate keeps its own metadata.
final class Catalog(final String? language, final Map<String, Entry> entries) {
  factory Catalog.parse(String text) {
    final entries = <String, Entry>{};
    String? language;
    var fields = <String, String>{};
    var fuzzy = false;
    String? field;
    for (final line in [...LineSplitter.split(text), '']) {
      if (fields.containsKey('msgstr') &&
          (line.isEmpty || line.startsWith('#') || line.startsWith('msg'))) {
        switch (fields) {
          case {'msgid': '', 'msgstr': final header}:
            language = RegExp(r'^Language: *(\S+)$', multiLine: true).firstMatch(header)?[1];
          case {'msgctxt': final context, 'msgid': final source, 'msgstr': final target}:
            entries[context] = (source: source, target: target, fuzzy: fuzzy);
        }
        (fields, fuzzy, field) = ({}, false, null);
      }
      switch (line) {
        case _ when line.startsWith('#,'):
          fuzzy = line.contains('fuzzy');
        case _ when line.startsWith('"') && field != null:
          fields[field] = fields[field]! + _unquote(line);
        case _ when line.startsWith('msg'):
          final space = line.indexOf(' ');
          field = line.substring(0, space);
          fields[field] = _unquote(line.substring(space + 1));
      }
    }
    return Catalog(language, entries);
  }

  int get translated => entries.values.where((entry) => entry.target.isNotEmpty).length;

  @override
  String toString() => [
    [
      'msgid ""',
      'msgstr ""',
      r'"Project-Id-Version: World of Horror\n"',
      if (language != null) '"Language: $language\\n"',
      r'"MIME-Version: 1.0\n"',
      r'"Content-Type: text/plain; charset=UTF-8\n"',
      r'"Content-Transfer-Encoding: 8bit\n"',
    ],
    for (final MapEntry(key: context, value: (:source, :target, :fuzzy)) in entries.entries)
      [
        if (fuzzy) '#, fuzzy',
        'msgctxt ${_quote(context)}',
        'msgid ${_quote(source)}',
        'msgstr ${_quote(target)}',
      ],
  ].map((block) => '${block.join('\n')}\n').join('\n');
}

/// Multiline strings start with `""` and break after each `\n`, as msgcat does.
String _quote(String text) {
  final lines = [
    for (final match in RegExp(r'[^\n]*\n|[^\n]+').allMatches(text))
      '"${match[0]!.replaceAllMapped(RegExp('[\\\\"\n\t\r]'), (m) => switch (m[0]!) {
        '\n' => r'\n',
        '\t' => r'\t',
        '\r' => r'\r',
        final char => '\\$char',
      })}"',
  ];
  return switch (lines) {
    [] => '""',
    [final line] => line,
    _ => '""\n${lines.join('\n')}',
  };
}

String _unquote(String quoted) => RegExp(r'"(.*)"')
    .firstMatch(quoted)![1]!
    .replaceAllMapped(
      RegExp(r'\\(.)'),
      (m) => switch (m[1]!) {
        'n' => '\n',
        't' => '\t',
        'r' => '\r',
        final char => char,
      },
    );

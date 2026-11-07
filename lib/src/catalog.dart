import 'dart:convert';

/// A text of the game. [notes] and [flags] travel as `#.` and `#,` comments,
/// which Weblate shows as the string description and applies as check flags;
/// [previous] is the source a fuzzy translation was made for (`#| msgid`).
typedef Entry = ({
  String source,
  String target,
  bool fuzzy,
  String previous,
  String notes,
  String flags,
});

extension Translate on Entry {
  Entry translate(String target, {bool fuzzy = false, String previous = ''}) => (
    source: source,
    target: target,
    fuzzy: fuzzy,
    previous: previous,
    notes: notes,
    flags: flags,
  );
}

/// Gettext catalog whose entries are keyed by `msgctxt`.
///
/// Translator comments, obsolete entries and plural forms are discarded: the
/// game has no use for them and Weblate keeps its own metadata.
final class Catalog(final String? language, final Map<String, Entry> entries) {
  factory Catalog.parse(String text) {
    final entries = <String, Entry>{};
    String? language;
    var fields = <String, String>{};
    var (notes, flags, fuzzy) = (<String>[], <String>[], false);
    String? field;
    for (final line in [...LineSplitter.split(text), '']) {
      if (fields.containsKey('msgstr') &&
          (line.isEmpty || line.startsWith('#') || line.startsWith('msg'))) {
        switch (fields) {
          case {'msgid': '', 'msgstr': final header} when !fields.containsKey('msgctxt'):
            language = RegExp(r'^Language: *(\S+)$', multiLine: true).firstMatch(header)?[1];
          case {'msgctxt': final context, 'msgid': final source, 'msgstr': final target}:
            entries[context] = (
              source: source,
              target: target,
              fuzzy: fuzzy,
              previous: fields['#|msgid'] ?? '',
              notes: notes.join('\n'),
              flags: flags.join(', '),
            );
        }
        (fields, notes, flags, fuzzy, field) = ({}, [], [], false, null);
      }
      // `#|` lines hold the previous msgid with the same syntax as the current one.
      final (prefix, body) = line.startsWith('#| ') ? ('#|', line.substring(3)) : ('', line);
      switch (body) {
        case _ when body.startsWith('#.'):
          notes.add(body.substring(2).trim());
        case _ when body.startsWith('#,'):
          final typed = body.substring(2).split(',').map((flag) => flag.trim());
          fuzzy = typed.contains('fuzzy');
          flags.addAll(typed.where((flag) => flag != 'fuzzy'));
        case _ when body.startsWith('"') && field != null:
          fields[field] = fields[field]! + _unquote(body);
        case _ when body.startsWith('msg'):
          final space = body.indexOf(' ');
          field = '$prefix${body.substring(0, space)}';
          fields[field] = _unquote(body.substring(space + 1));
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
    for (final MapEntry(key: context, value: entry) in entries.entries)
      [
        if (entry.notes.isNotEmpty) ...entry.notes.split('\n').map((note) => '#. $note'),
        if ([if (entry.fuzzy) 'fuzzy', if (entry.flags.isNotEmpty) entry.flags]
            case [_, ...] && final flags)
          '#, ${flags.join(', ')}',
        if (entry.fuzzy && entry.previous.isNotEmpty)
          ...'msgid ${_quote(entry.previous)}'.split('\n').map((line) => '#| $line'),
        'msgctxt ${_quote(context)}',
        'msgid ${_quote(entry.source)}',
        'msgstr ${_quote(entry.target)}',
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

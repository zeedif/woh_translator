import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:woh_translator/woh_translator.dart';

/// Locale of each language folder the game loads. Japanese has no folder: it
/// is the second column of every English file. Any other translation has to
/// replace the English folder to be loaded.
const locales = {
  'eng': 'en',
  'chs': 'zh_Hans',
  'cht': 'zh_Hant',
  'fra': 'fr',
  'ger': 'de',
  'kor': 'ko',
  'pol': 'pl',
  'tur': 'tr',
  'ukr': 'uk',
};

/// The game breaks lines with `#`; catalogs use `\n` so Weblate can check them.
extension on String {
  String get fromJn => replaceAll('#', '\n');
  String get toJn => replaceAll('\n', '#');
}

/// Lines of a `.jn` file and the terminator that joins them back unchanged.
(List<String>, String) readJn(File file) {
  final text = file.readAsStringSync();
  final newline = text.contains('\r\n') ? '\r\n' : '\n';
  return (text.split(newline), newline);
}

List<File> jnFiles(Directory folder) =>
    folder.listSync().whereType<File>().where((file) => file.path.endsWith('.jn')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Columns of every line in [folder], keyed by `file:line`.
Map<String, List<String>> readFolder(Directory folder) => {
  for (final file in jnFiles(folder))
    for (final (index, line) in readJn(file).$1.indexed)
      '${p.basenameWithoutExtension(file.path)}:$index': line.split('|'),
};

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'game',
      abbr: 'g',
      help: 'Carpeta de instalación del juego.',
      defaultsTo: r'C:\Program Files (x86)\Steam\steamapps\common\WOH',
    )
    ..addOption(
      'out',
      abbr: 'o',
      help: 'Carpeta de salida (language/ al extraer o importar, build/ al generar).',
    )
    ..addOption('locale', abbr: 'l', help: 'Al importar, código del idioma de la carpeta.')
    ..addFlag('fuzzy', negatable: false, help: 'Al generar, incluye las traducciones en borrador.')
    ..addFlag(
      'keys',
      negatable: false,
      help: 'Al generar, antepone a cada texto su archivo:línea para ubicarlo en el juego.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final options = parser.parse(arguments);
  final language = Directory(p.join(options.option('game')!, 'language'));
  final english = Directory(p.join(language.path, 'engLanguage'));
  final command = options.flag('help') ? const <String>[] : options.rest;
  if (command.isNotEmpty && !english.existsSync()) {
    stderr.writeln('No se encontró ${english.path}; indica la carpeta del juego con --game.');
    exitCode = 66;
    return;
  }

  late final eng = readFolder(english);
  late final sources = {
    for (final MapEntry(key: context, value: [text, ...]) in eng.entries)
      if (text.isNotEmpty) context: text.fromJn,
  };
  late final template = {
    for (final MapEntry(key: context, value: (:notes, :flags)) in describe(sources).entries)
      context: (
        source: sources[context]!,
        target: '',
        fuzzy: false,
        previous: '',
        notes: notes,
        flags: flags,
      ),
  };
  final out = options.option('out');

  switch (command) {
    case ['extract']:
      final folder = Directory(out ?? 'language')..createSync(recursive: true);
      final catalogs = {
        'woh.pot': Catalog(null, template),
        for (final MapEntry(key: locale, value: rows) in {
          'ja': {
            for (final MapEntry(:key, value: columns) in eng.entries) key: columns.skip(1).toList(),
          },
          for (final directory in language.listSync().whereType<Directory>())
            if (locales[RegExp(r'^(\w+)Language$').firstMatch(p.basename(directory.path))?[1]]
                case final locale? when locale != 'en')
              locale: readFolder(directory),
        }.entries)
          if (rows.isNotEmpty)
            '$locale.po': Catalog(locale, {
              for (final MapEntry(key: context, value: entry) in template.entries)
                context: switch (rows[context]) {
                  [final translation, ...] => entry.translate(translation.fromJn),
                  _ => entry,
                },
            }),
      };

      // Catalogs the game does not ship are updated as msgmerge would, also
      // following the texts the update moved to another line.
      for (final file in folder.listSync().whereType<File>()) {
        if (p.basename(file.path) case final name
            when name.endsWith('.po') && !catalogs.containsKey(name)) {
          final old = Catalog.parse(file.readAsStringSync());
          final displaced = {
            for (final MapEntry(key: context, value: entry) in old.entries.entries)
              if (entry.target.isNotEmpty && template[context]?.source != entry.source)
                entry.source: entry,
          };
          catalogs[name] = Catalog(old.language ?? p.basenameWithoutExtension(name), {
            for (final MapEntry(key: context, value: entry) in template.entries)
              context: switch ((old.entries[context], displaced[entry.source])) {
                (final kept?, _) when kept.source == entry.source => entry.translate(
                  kept.target,
                  fuzzy: kept.fuzzy,
                  previous: kept.previous,
                ),
                (_, final moved?) => entry.translate(
                  moved.target,
                  fuzzy: moved.fuzzy,
                  previous: moved.previous,
                ),
                (final changed?, _)
                    when changed.target.isNotEmpty && !sources.containsValue(changed.source) =>
                  entry.translate(changed.target, fuzzy: true, previous: changed.source),
                _ => entry,
              },
          });
        }
      }
      for (final MapEntry(key: name, value: catalog) in catalogs.entries) {
        File(p.join(folder.path, name)).writeAsStringSync('$catalog');
        print('${catalog.language ?? 'plantilla'}: ${catalog.translated}/${template.length}');
      }

    case ['import', final path] when options.option('locale') != null:
      final mod = <String, List<String>>{};
      for (final file in jnFiles(Directory(path))) {
        final name = p.basenameWithoutExtension(file.path);
        final lines = readJn(file).$1;
        // Some mods break a text with a real line break: the first half lacks
        // the Japanese column and the second one starts with the game's `#`.
        for (
          var i = 0;
          i + 1 < lines.length && !eng.containsKey('$name:${lines.length - 1}');
          i++
        ) {
          if (!lines[i].contains('|') && lines[i + 1].startsWith('#'))
            lines[i] += lines.removeAt(i + 1);
        }
        for (final (index, line) in lines.indexed) {
          mod['$name:$index'] = line.split('|');
        }
      }
      // A mod keeps the Japanese column of the version it was made for, so a
      // different one means the English text changed since.
      String japanese(List<String> row) => String.fromCharCodes(
        row
            .skip(1)
            .join()
            .runes
            .map((rune) => rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune),
      ).replaceAll(RegExp(r'[\s#\\]'), '');
      final catalog = Catalog(options.option('locale'), {
        for (final MapEntry(key: context, value: entry) in template.entries)
          context: switch (mod[context]) {
            [final translation, ...] && final row => entry.translate(
              translation.fromJn,
              fuzzy: switch (japanese(row)) {
                '' => false,
                final own => own != japanese(eng[context]!),
              },
            ),
            _ => entry,
          },
      });
      final file = File(p.join(out ?? 'language', '${catalog.language}.po'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$catalog');
      print(
        '${catalog.language}: ${catalog.translated}/${template.length} '
        '(${catalog.entries.values.where((entry) => entry.fuzzy).length} en borrador) en ${file.path}',
      );

    case ['build', final path]:
      final catalog = Catalog.parse(File(path).readAsStringSync());
      final locale = catalog.language ?? p.basenameWithoutExtension(path);
      final translations = {
        for (final MapEntry(key: context, value: entry) in catalog.entries.entries)
          if (entry.target.isNotEmpty && (!entry.fuzzy || options.flag('fuzzy')))
            context: entry.target.toJn,
      };
      final folder = Directory(
        p.join(
          out ?? 'build',
          '${{for (final MapEntry(:key, :value) in locales.entries) value: key}[locale] ?? 'eng'}Language',
        ),
      )..createSync(recursive: true);
      for (final file in jnFiles(english)) {
        final name = p.basenameWithoutExtension(file.path);
        final (lines, newline) = readJn(file);
        File(p.join(folder.path, p.basename(file.path))).writeAsStringSync(
          [
            for (final (index, line) in lines.indexed)
              switch ((translations['$name:$index'], line.split('|'))) {
                (final text?, [_, ...final rest]) when !options.flag('keys') => [
                  text,
                  ...rest,
                ].join('|'),
                (final text, [final source, ...final rest])
                    when options.flag('keys') && source.isNotEmpty =>
                  ['[${name.substring(4)}:$index]${text ?? source}', ...rest].join('|'),
                _ => line,
              },
          ].join(newline),
        );
      }
      print('${translations.length} textos de $locale aplicados en ${folder.path}');

    default:
      print(
        'Uso: woh_translator <extract | import carpeta --locale código | build archivo.po> '
        '[opciones]\n\n${parser.usage}',
      );
      exitCode = options.flag('help') ? 0 : 64;
  }
}

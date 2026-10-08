import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:woh_translator/woh_translator.dart';

/// Locale of each folder prefix in the game's `language` directory. Japanese
/// has no folder: it is the second column of every English file.
const locales = {
  'eng': 'en',
  'chs': 'zh_Hans',
  'cht': 'zh_Hant',
  'fra': 'fr',
  'ger': 'de',
  'kor': 'ko',
  'pol': 'pl',
  'spa': 'es',
  'lat': 'es_419',
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
      help: 'Carpeta de salida (language/ al extraer, build/ al generar).',
    )
    ..addFlag('fuzzy', negatable: false, help: 'Al generar, incluye las traducciones en borrador.')
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

  switch (command) {
    case ['extract']:
      final folders = {
        for (final folder in language.listSync().whereType<Directory>())
          if (RegExp(r'^(\w+)Language$').firstMatch(p.basename(folder.path)) case final match?)
            match[1]!: {
              for (final file in jnFiles(folder))
                for (final (index, line) in readJn(file).$1.indexed)
                  '${p.basenameWithoutExtension(file.path)}:$index': line.split('|'),
            },
      };
      final eng = folders.remove('eng')!;
      final source = {
        for (final MapEntry(key: context, value: [text, ...]) in eng.entries)
          if (text.isNotEmpty) context: text.fromJn,
      };
      final out = Directory(options.option('out') ?? 'language')..createSync(recursive: true);
      for (final MapEntry(key: locale, value: targets) in {
        null: const <String, List<String>>{},
        'ja': {
          for (final MapEntry(:key, value: columns) in eng.entries) key: columns.skip(1).toList(),
        },
        for (final MapEntry(key: prefix, value: rows) in folders.entries)
          if (rows.isNotEmpty) locales[prefix] ?? prefix: rows,
      }.entries) {
        final catalog = Catalog(locale, {
          for (final MapEntry(key: context, value: text) in source.entries)
            context: (
              source: text,
              target: switch (targets[context]) {
                [final translation, ...] => translation.fromJn,
                _ => '',
              },
              fuzzy: false,
            ),
        });
        File(p.join(out.path, locale == null ? 'woh.pot' : '$locale.po'))
            .writeAsStringSync('$catalog');
        print('${locale ?? 'plantilla'}: ${catalog.translated}/${source.length}');
      }

    case ['build', final path]:
      final catalog = Catalog.parse(File(path).readAsStringSync());
      final locale = catalog.language ?? p.basenameWithoutExtension(path);
      final translations = {
        for (final MapEntry(key: context, value: (:target, :fuzzy, source: _))
            in catalog.entries.entries)
          if (target.isNotEmpty && (!fuzzy || options.flag('fuzzy'))) context: target.toJn,
      };
      final folder = Directory(
        p.join(
          options.option('out') ?? 'build',
          '${{for (final MapEntry(:key, :value) in locales.entries) value: key}[locale] ?? locale}Language',
        ),
      )..createSync(recursive: true);
      for (final file in jnFiles(english)) {
        final (lines, newline) = readJn(file);
        File(p.join(folder.path, p.basename(file.path))).writeAsStringSync(
          [
            for (final (index, line) in lines.indexed)
              switch (translations['${p.basenameWithoutExtension(file.path)}:$index']) {
                final translation? => [translation, ...line.split('|').skip(1)].join('|'),
                null => line,
              },
          ].join(newline),
        );
      }
      print('${translations.length} textos de $locale aplicados en ${folder.path}');

    default:
      print('Uso: woh_translator <extract | build archivo.po> [opciones]\n\n${parser.usage}');
      exitCode = options.flag('help') ? 0 : 64;
  }
}

import 'package:test/test.dart';
import 'package:woh_translator/woh_translator.dart';

void main() {
  test('round-trips escapes, line breaks, notes, flags and previous sources', () {
    final catalog = Catalog('es', {
      'woh_ui:0': (
        source: 'English',
        target: 'Español',
        fuzzy: false,
        previous: '',
        notes: '',
        flags: '',
      ),
      'woh_event:7': (
        source: 'Say "hi"\n\n[leave]\tC:\\',
        target: 'Di "hola"\n\n[irse]\tC:\\',
        fuzzy: true,
        previous: 'Say hi\n[leave]',
        notes: 'Opción de «EVENT».\nDiálogo de KANA.',
        flags: '',
      ),
      'woh_hachi:0': (
        source: 'x',
        target: '',
        fuzzy: false,
        previous: '',
        notes: 'Marcador.',
        flags: 'read-only',
      ),
    });

    final parsed = Catalog.parse('$catalog');

    expect(parsed.language, 'es');
    expect(parsed.entries, catalog.entries);
    expect(parsed.translated, 2);
  });

  test('ignores translator comments and obsolete entries written by Weblate', () {
    final parsed = Catalog.parse(r'''
# Translators comment
msgid ""
msgstr ""
"Language: es_419\n"
"Plural-Forms: nplurals=2; plural=n != 1;\n"

# translator
#. extracted
#, fuzzy, read-only
#| msgctxt "woh_mys:3"
#| msgid "First"
msgctxt "woh_mys:3"
msgid ""
"First\n"
"second"
msgstr "Primero\n"
"segundo"
#~ msgctxt "woh_old:1"
#~ msgid "Old"
#~ msgstr "Viejo"
''');

    expect(parsed.language, 'es_419');
    expect(parsed.entries, {
      'woh_mys:3': (
        source: 'First\nsecond',
        target: 'Primero\nsegundo',
        fuzzy: true,
        previous: 'First',
        notes: 'extracted',
        flags: 'read-only',
      ),
    });
  });

  test('describes events, their options, results and speakers', () {
    final context = describe({
      'woh_event:0': 'GRUESOME ALTAR',
      'woh_event:1': 'Seeing the two chopped-off heads, you wonder who has been cooking for you.',
      'woh_event:2': 'research occult notes',
      'woh_event:3': 'call the police',
      'woh_event:4': '[call the police]\nThe officer is grateful.',
      'woh_event:5': '[NEEDS \'SECOND SIGHT\' SKILL]',
      'woh_event:6': 'consult the ghosts',
      'woh_event:7': '<<Sorry about all this,>> JUNPEI says again.',
      'woh_event:8': 'EXHAUSTED',
      'woh_hachi:0': 'xxx',
    });

    expect(
      context['woh_event:2']!.notes,
      contains(
        'Opciones: research occult notes · '
        'call the police · consult the ghosts.',
      ),
    );
    expect(context['woh_event:4']!.notes, contains('Resultado de la opción «call the police»'));
    expect(context['woh_event:5']!.notes, contains('Requisito'));
    expect(context['woh_event:7']!.notes, contains('Diálogo de JUNPEI.'));
    expect(context['woh_event:8']!.notes, isNot(contains('GRUESOME ALTAR')));
    expect(context['woh_hachi:0']!.flags, 'read-only');
  });
}

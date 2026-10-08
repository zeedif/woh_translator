import 'package:test/test.dart';
import 'package:woh_translator/woh_translator.dart';

void main() {
  test('round-trips escapes, line breaks and fuzzy state', () {
    final catalog = Catalog('es', {
      'woh_ui:0': (source: 'English', target: 'Español', fuzzy: false),
      'woh_event:7': (
        source: 'Say "hi"\n\n[leave]\tC:\\',
        target: 'Di "hola"\n\n[irse]\tC:\\',
        fuzzy: true,
      ),
      'woh_ui:157': (source: ' [strength check]', target: '', fuzzy: false),
    });

    final parsed = Catalog.parse('$catalog');

    expect(parsed.language, 'es');
    expect(parsed.entries, catalog.entries);
    expect(parsed.translated, 2);
  });

  test('ignores comments and obsolete entries written by Weblate', () {
    final parsed = Catalog.parse(r'''
# Translators comment
msgid ""
msgstr ""
"Language: es_419\n"
"Plural-Forms: nplurals=2; plural=n != 1;\n"

#. extracted
#, fuzzy, c-format
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
      'woh_mys:3': (source: 'First\nsecond', target: 'Primero\nsegundo', fuzzy: true),
    });
  });
}

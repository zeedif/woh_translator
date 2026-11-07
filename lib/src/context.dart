typedef Context = ({String notes, String flags});

/// Files whose texts all belong to the same part of the game.
const _files = {
  'woh_ui': 'Interfaz: menús, opciones y botones.',
  'woh_small': 'Objetos: etiquetas, estadísticas, descripciones y mensajes de uso.',
  'woh_perk': 'Mejoras (perks): nombre, efecto y mensaje al activarse.',
  'woh_spell': 'Hechizos: tipos, efectos y mensajes al lanzarlos.',
  'woh_enm': 'Enemigos: tipos, descripciones y mensajes de combate.',
  'woh_event': 'Eventos al investigar un lugar.',
  'woh_mys': 'Misterios: introducción, pasos, encuentros y finales.',
  'woh_palette': 'Nombre de una paleta de colores.',
  'woh_mod': 'Menú de mods y eventos personalizados.',
  'woh_ver': 'Notas de una versión del juego.',
};

enum _Role { title, body, option, requirement, rest }

const _name = r"[A-Z][A-Z'’\-]+(?: [A-Z][A-Z'’\-]+)*";

/// `NAME: <<…`, `<<…>> NAME says` and `NAME frowns. <<…`.
final _speakers = [
  RegExp('(?:^|\\n)($_name):\\s*<<'),
  RegExp('>>,?\\s+($_name)\\s+[a-z]'),
  RegExp('(?:^|\\n|[.!?] )($_name) [a-z][^<\\n]*<<'),
];

/// Notes and Weblate flags inferred from how the game lays out each file: a
/// short title in capitals followed by a long text opens a block (an event,
/// an item, an enemy…) whose short lines right after that text are options.
/// The block ends at the next line in capitals that does not open another.
Map<String, Context> describe(Map<String, String> sources) {
  final files = <String, List<(int, String)>>{};
  for (final MapEntry(key: context, value: text) in sources.entries) {
    final [file, index] = context.split(':');
    (files[file] ??= []).add((int.parse(index), text));
  }
  bool isShort(String text) =>
      text.length <= 60 && '\n'.allMatches(text).length <= 1 && !RegExp(r'[.!…:]$').hasMatch(text);
  bool isCaps(String text) => text.contains(RegExp('[A-Z]')) && !text.contains(RegExp('[a-z]'));

  final result = <String, Context>{};
  for (final MapEntry(key: file, value: lines) in files.entries) {
    final roles = <(_Role, int?)>[];
    int? open;
    for (final (i, (index, text)) in lines.indexed) {
      final next = i + 1 < lines.length && lines[i + 1].$1 == index + 1 ? lines[i + 1].$2 : '';
      final role = switch (roles.lastOrNull?.$1) {
        _Role.title => _Role.body,
        _ when text.startsWith('[NEEDS') => _Role.requirement,
        _Role.body || _Role.option || _Role.requirement when isShort(text) => _Role.option,
        _ when open != null && isShort(text) && next.startsWith('[NEEDS') => _Role.option,
        // Interface texts follow no such layout.
        _ when file != 'woh_ui' &&
                isCaps(text) &&
                isShort(text) &&
                RegExp(r'^[A-Z][^\n]*$').hasMatch(text) &&
                next.length >= 60 =>
          _Role.title,
        _ => _Role.rest,
      };
      open = switch (role) {
        _Role.title => i,
        _Role.rest when isCaps(text) && isShort(text) => null,
        _ => open,
      };
      roles.add((role, open));
    }

    final options = <int, List<String>>{};
    for (final (i, (role, block)) in roles.indexed) {
      if ((role, block) case (_Role.option, final block?)) (options[block] ??= []).add(lines[i].$2);
    }
    for (final (i, (index, text)) in lines.indexed) {
      final (role, block) = roles[i];
      final title = block == null ? '' : '«${lines[block].$2}» ($file:${lines[block].$1})';
      final siblings = options[block] ?? const [];
      final placeholder = RegExp(r'^x+$').hasMatch(text);
      result['$file:$index'] = (
        notes: [
          ?_files[file],
          if (index == 0 && (text == 'eng' || text == 'English'))
            'Nombre o código del idioma de esta traducción.',
          if (placeholder) 'Marcador de posición del juego, sin texto real.',
          if (block != null)
            switch (role) {
              _Role.title => 'Título; los textos siguientes forman parte de su bloque.',
              _Role.body => 'Descripción de $title.',
              _Role.option =>
                'Opción de $title. Opciones: ${siblings.map((option) => option.replaceAll('\n', ' / ')).join(' · ')}.',
              _Role.requirement => 'Requisito de una opción de $title.',
              _Role.rest => switch (RegExp(r'^\[([^\]\n]+)\]\n').firstMatch(text)?[1]) {
                final option? when siblings.contains(option) =>
                  'Resultado de la opción «$option» de $title.',
                _ => 'Parte de $title.',
              },
            },
          if (text.contains('<<'))
            switch ({
              for (final pattern in _speakers)
                for (final match in pattern.allMatches(text)) match[1]!,
            }) {
              final speakers when speakers.isNotEmpty => 'Diálogo de ${speakers.join(', ')}.',
              _ => 'Diálogo o pensamiento entre << >>.',
            },
        ].join('\n'),
        flags: placeholder ? 'read-only' : '',
      );
    }
  }
  return result;
}

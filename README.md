# WOH Translator

Herramienta para traducir *World of Horror* (PC/Steam) con gettext y Weblate.

El juego guarda sus textos en archivos `.jn` dentro de `language/<código>Language/`:
una línea por texto, el idioma en la primera columna y el japonés en la segunda
(separadas por `|`), y `#` como salto de línea. Esta herramienta convierte esos
archivos en catálogos PO identificados por `archivo:línea` y, a la inversa, genera
una carpeta de idioma lista para el juego a partir de un PO.

## Uso

Requiere el [Dart SDK](https://dart.dev/get-dart) 3.13 o superior.

```bash
dart pub get

# Extrae la plantilla language/woh.pot y un PO por cada idioma incluido en el juego.
dart run woh_translator extract --game "D:\Juegos\SteamLibrary\steamapps\common\WOH"

# Genera build/spaLanguage aplicando language/es.po sobre los textos en inglés.
dart run woh_translator build language/es.po --game "D:\Juegos\SteamLibrary\steamapps\common\WOH"
```

Copia la carpeta generada en `language/` dentro del juego. Los textos sin traducir
se quedan en inglés; los marcados como borrador solo se incluyen con `--fuzzy`.

## Idiomas

| Archivo | Origen |
| --- | --- |
| `woh.pot` | Inglés (`engLanguage`) |
| `ja.po` | Segunda columna de `engLanguage` |
| `zh_Hans.po`, `zh_Hant.po`, `fr.po`, `de.po`, `ko.po`, `pl.po` | Traducciones oficiales |
| `es_419.po` | Traducción de la comunidad al español latinoamericano (`latLanguage`) |
| `es.po` | Traducción al español en curso |

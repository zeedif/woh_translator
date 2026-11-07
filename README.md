# WOH Translator

Herramienta para traducir *World of Horror* (PC/Steam) con gettext y Weblate.

El juego guarda sus textos en archivos `.jn` dentro de `language/<código>Language/`:
una línea por texto, el idioma en la primera columna y el japonés en la segunda
(separadas por `|`), y `#` como salto de línea. Esta herramienta convierte esos
archivos en catálogos PO identificados por `archivo:línea` y, a la inversa, genera
una carpeta de idioma lista para el juego a partir de un PO.

Los catálogos corresponden a la versión 1.2 del juego (*As Below So Above*).

## Uso

Requiere el [Dart SDK](https://dart.dev/get-dart) 3.13 o superior.

```bash
dart pub get

# Extrae la plantilla language/woh.pot y un PO por cada idioma incluido en el juego,
# y actualiza el resto de los PO de language/ con los textos nuevos o cambiados.
dart run woh_translator extract --game "D:\Juegos\SteamLibrary\steamapps\common\WOH"

# Convierte la carpeta de un mod de traducción en language/es_ES.po.
dart run woh_translator import "ruta\al\mod\engLanguage" --locale es_ES --game "..."

# Genera build/engLanguage aplicando language/es.po sobre los textos en inglés.
dart run woh_translator build language/es.po --game "..."
```

El juego solo carga sus carpetas oficiales, así que una traducción de la comunidad
se genera como `engLanguage` y reemplaza al inglés: respalda la carpeta original
antes de copiarla en `language/` dentro del juego. Los textos sin traducir se quedan
en inglés; los marcados como borrador solo se incluyen con `--fuzzy`.

Al actualizar el juego, `extract` hace con los PO que no vienen del juego lo mismo
que `msgmerge`: conserva las traducciones, marca como borrador las de los textos que
cambiaron (con el texto anterior, para que Weblate muestre la diferencia) y sigue a
los textos que se movieron de línea.

## Contexto para traducir

Cada texto lleva notas (`#.`) que Weblate muestra junto a la cadena. Se deducen del
orden de los archivos: el tipo de contenido del archivo, el bloque (evento, objeto,
enemigo…) al que pertenece cada texto, las opciones hermanas de un mismo evento, el
resultado de cada opción y quién habla en los diálogos `<<…>>`. Los marcadores de
posición del juego (`x`) llevan la marca `read-only`.

Para ubicar un texto en pantalla, genera la carpeta con `--keys`: cada texto empieza
con su `[archivo:línea]` (por ejemplo `[event:12]`), que coincide con el contexto del
PO. Así también se ven los textos que el juego une a otros.

## Idiomas

| Archivo | Origen |
| --- | --- |
| `woh.pot` | Inglés (`engLanguage`) |
| `ja.po` | Segunda columna de `engLanguage` |
| `zh_Hans.po`, `zh_Hant.po`, `fr.po`, `de.po`, `ko.po`, `pl.po` | Traducciones oficiales |
| `es_419.po` | [Parche esp latinoamericano](https://www.nexusmods.com/worldofhorror/mods/15) de Asenath42 (versión 1.01, hecha para la 1.0 del juego) |
| `es.po` | Traducción al español en curso |

## Créditos

Las traducciones de la comunidad pertenecen a sus autores; este repositorio solo las
convierte a PO como referencia. Descárgalas, comenta y apoya su trabajo en Nexus Mods:

- **Asenath42**: [Latin American Spanish Translation Patch](https://www.nexusmods.com/worldofhorror/mods/15)
  ([portafolio](https://eldritchcoffee.neocities.org), [Ko-fi](https://ko-fi.com/asenath)).

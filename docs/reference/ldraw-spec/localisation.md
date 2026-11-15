<!-- Source: https://www.ldraw.org/article/559.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Localisation Guideline

**Maintained by:** LDraw.org Standards Board\
**Revision:** 06-Jan-2010

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="specification"></span>

### Specification

A guideline for implementing localisations for the LDraw System of Tools.

<span id="format"></span>

### Format

<span id="encoding"></span>

#### Encoding

The translation file has to be stored encoded by UTF-8.

<span id="line_termination"></span>

#### Line Termination

Line Termination of this file is CrLf. Please see: [LDraw.org File Format Restrictions for the Official Library](https://www.ldraw.org/article/512).

<span id="directory"></span>

### Directory

The translations files are stored in the following folder:

`<LDRAWBASEDIR>\localisations\<language ISO 639-1 in lower case>[-<country ISO 3166-1 alpha-2 in upper case>]`

Please note the dash between the language and the optional country code. The optional country code is only needed if there is more than one translations for a language that depends on the region where that language is used (For example German or English language, that is used also in other countries where it is slightly different but still that language.) In those cases the most common idiom is used as the default language without country code and the additionally language is marked additionally with the country code. (Example: Language is German, if there will be then the Swiss German translation added the German-Germany translation is marked with de and the German-Swiss translation is marked with `de-CH`)\
So if then someone wants to have the German-Austria translation (`de-AT`) and that is not avilable the user gets the de translation instead. If there is also no translation in the de the native language of LDraw.org is used (Australian English).\
Because of the native language of LDraw.org (Australian Engish) it is necessary for the English language to carry in every case the country code and there should not be any en folder in the localisations folder, only `en-<country code>` labled folder.

The translations for the part descriptions are stored in a file called "`parts.txt`"\
The translations for the colour names are stored in a file called "`colours.txt`"\
The translations for the category names are stored in a file called "`categories.txt`"\
The keywords for each part are stored in a file called "`keywords.txt`"

<span id="header_information"></span>

### Header

Header of the translation files:

    0 LDraw.org Configuration File
    0 Name: colours.txt
    0 Author: LDraw.org
    0 !LDRAW_ORG Configuration UPDATE 2009-09-05
    0 !TRANSLATION COLOURS de-DE
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt

Please note that also other comment lines can be added such as `0 !HISTORY` to reflect the changes that has been made.

All lines that are not starting with a `0` (zero) will be treated as an translation entry that has to follow the rules described below: The first four lines are described in [LDraw.org Official Library Header Specification](https://www.ldraw.org/article/398) and are adopted for these files as follows:

`0 LDraw.org Configuration File` - Always this text if official document.\
`0 Name: colours.txt` - filename not limited to dat or ldr\
`0 Author: LDraw.org` - LDraw.org if official document. Can be also another author name.\
`0 !LDRAW_ORG Configuration UPDATE 2009-09-05` - See: [LDraw.org Colour Definition Language Extension](https://www.ldraw.org/article/299)

If it is an official LDraw.org document then a line with the following content is necessary:

`0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt `

<span id="translation"></span>

#### Translation Files

The following line applies for translation files and will be described below:

`0 !TRANSLATION <type of content> <language ISO 639-1 in lower case>[-<country ISO 3166-1 alpha-2 in upper case>]`\
(Please note the dash between the language and the country code. Country code is optional, please see above.)

Where:

- `<type of content>` can have the following content `COLOURS, PARTS, CATEGORIES, KEYWORDS` but is not limited to that. This is also the name of the file in upper case whereas the filename itself is always lower case!
- `<language ISO 639-1 in lower case>` - See <a href="https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes" target="_blank">http://en.wikipedia.org/wiki/List_of_ISO_639-1_codes</a> for valid codes.
- `<country ISO 3166-1 alpha-2 in upper case>` - See <a href="https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2" target="_blank">http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2</a> for valid codes.

<span id="type_of_content"></span>

#### Type of content

Translation section for `COLOURS, PARTS, CATEGORIES` and` KEYWORDS`\
\
`"<neutral language>" = "<translation language>"`

Where:

- `<neutral language>` is in any case Australian english. This is also the fallback language if a translation is not found (language used in the part files itself). If a human readable version of the neutral language is needed then add a version of `en-AU` to your localisation folder.\
  Please note that the keywords are translated keyword by keyword ([LDraw.org CATEGORY and KEYWORDS Language Extension](https://www.ldraw.org/article/340))
- `<translation language>` is the language determined by the `<language short letter according ISO 639-1 in lower case>[-<country ISO 3166 in upper case>]`.

Both strings have to be sourrounded by " (doublequote). One or more whitespaces (space, tab) outside of the so delimited strings are allowed. There is no length restriction for these lines. If the string itself contains one of the following characters " (doublequote) or \\ (backslash) that characters needs a leading \\ (backslash). A single \\ (backslash) found in the file will be not processed. It will be deleted if not in front of " (doublequote) or \\ (backslash).

Example for this: Content of the file: `"Brick with \"\=\" Pattern"` will be parsed to `"Brick with "=" Pattern"`\
Example lines: `"Brick 1 x 1 with Blue \"0\" Pattern" = "Stein 1 x 1 mit Blau \"0\" Dekor"`\
As the translations strings are only 'virtual' and not coded in the file there are no other restrictions.

<span id="special"></span>

#### Special

To make life easier for translators the following key can be used for `~Moved to` files but it is not required.\
`"~Moved to %s" = "[...] %s [...]"`\
Application should ideally support both ways.

<span id="examples"></span>

### Examples

Here a sample for the `colours.txt`:

    0 LDraw.org Configuration File
    0 Name: colours.txt
    0 Author: LDraw.org
    0 !LDRAW_ORG Configuration UPDATE 2009-09-05
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt
    0 !TRANSLATION COLOURS de

    "Black" = "Schwarz"
    "Blue" = "Blau"
    "Green" = "Grün"
    "Dark_Turquoise" = "Dunkeltürkis"
    "Red" = "Rot"
    "Dark_Pink" = "Dunkelrosa"

and here a sample for the `parts.txt`:\
(Please note that the preceeding flags '~' (tilde) and '\_' (underscore) are forced to be carried on in the translation.)

    0 LDraw.org Configuration File
    0 Name: parts.txt
    0 Author: LDraw.org
    0 !LDRAW_ORG Configuration UPDATE 2009-09-05
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt
    0 !TRANSLATION PARTS de-DE

    "Animal Bat Wing 9 x 9 with Axle" = "Tier Fledermaus Flügel 9 x 9 mit Achse"
    "Animal Bird" = "Tier Vogel"
    "Animal Bird with Parrot Pattern" = "Tier Vogel mit Papagei Dekor"
    "Animal Cat Crouching" = "Tier Katze kauernd"
    "~Technic Pneumatic Cylinder with 2 Inlets Medium Slide" = "~Technik Pneumatik Zylinder mit 2 Einlässen Mittel Gleiter"
    "~Moved to 75974" = "~Verschoben nach 75974"
    "_Brick 2 x 2 White" = "_Stein 2 x 2 Weiss"
    "Brick 1 x 1 with Blue \"0\" Pattern" = "Stein 1 x 1 mit Blau \"0\" Dekor"

and here a sample for the `categories.txt`:

    0 LDraw.org Configuration File
    0 Name: categories.txt
    0 Author: LDraw.org
    0 !LDRAW_ORG Configuration UPDATE 2009-09-05
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt
    0 !TRANSLATION CATEGORIES de-DE

    "Animal" = "Tier"
    "Antenna" = "Antenne"
    "Arch" = "Bogen"

and here a sample for the `keywords.txt`:

    0 LDraw.org Configuration File
    0 Name: keywords.txt
    0 Author: LDraw.org
    0 !LDRAW_ORG Configuration UPDATE 2009-09-05
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt
    0 !TRANSLATION KEYWORDS de-DE

    "cone" = "Konus"
    "exhaust" = "Auspuff"

It is not forced for the translations to avoide double entry part description \<-\> keywords as it is difficult to compare those entries but should be avoided to minimize used discspace.

Applications should use translations only for presenting a string to the user and not to decide anything based on that translation string.

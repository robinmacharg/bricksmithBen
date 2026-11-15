<!-- Source: https://www.ldraw.org/article/398.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Official Library Header Specification

**Maintained by:** LDraw.org Library Administrator\
**Revision:** 21-Feb-2025

**Revision History:**\
29-Sep-2006: Added the "Unofficial\_" types to !LDRAW_ORG meta\
02-Oct-2006: Added "~Moved To" syntax\
06-Sep-2007: Added Alias and Physical_Color as optional qualifiers\
25-Dec-2015: Added defined desciption prefix character for programs that use parts.lst\
13-Sep-2017: Added Flexible_Section optional qualifier\
19-Aug-2019: Depreciated Physical_Color and made all parts the use it obsolete\
22-Nov-2023: Added new !LICENSE lines 21-Feb-2025: Added !PREVIEW meta

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="Spec"></span>

### Purpose

LDraw Official Library header format suitable for the implementation of the [Contributor Agreement](https://www.ldraw.org/article/349) (CA).

<span id="Scope"></span>

### Scope

The header has to identify the LDraw.org username - the basis upon which CA affirmation is assessed - and if the part is covered by the CA or not. It has to conform to the new meta command syntax, where backwards compatibility allows this, as well as structure the history comment lines. No other meta-commands are allowed in the part header other than those specified in this document

<span id="Syntax"></span>

### Syntax

` 0 `*`PartDescription`*\
`0 Name: `*`Filename.dat`*\
`0 Author: `*`RealName`*` [`*`UserName`*`]`\
`0 !LDRAW_ORG Part| Subpart| Primitive| 8_Primitive| 48_Primitive| Shortcut (optional qualifier(s)) ORIGINAL|UPDATE YYYY-RR`\
or\
`0 !LDRAW_ORG Unofficial_Part| Unofficial_Subpart| Unofficial_Primitive| Unofficial_8_Primitive| Unofficial_48_Primitive| Unofficial_Shortcut (optional qualifier(s))`\
`0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt `\
or\
` 0 !LICENSE Licensed under CC BY 2.0 and CC BY 4.0 : see CAreadme.txt `\
or\
` 0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt `\
or\
` 0 !LICENSE Not redistributable : see NonCAreadme.txt `

` 0 !HELP `*`Optional free text description of file usage`*\
`0 !HELP `*`Second row after user's line break to simulate paragraph`*` `

` 0 BFC ( CERTIFY ( CCW | CW ) | NOCERTIFY ) `

` 0 !CATEGORY `*`Category name`*\
`0 !KEYWORDS `*`words, more words,...,`*\
`0 !KEYWORDS `*`words in second row, ..., final words`*` `

` 0 !CMDLINE LDraw run-time command(s) `

` 0 !PREVIEW <colour> x y z a b c d e f g h i `

` 0 !HISTORY YYYY-MM-DD [`*`UserName`*`] `*`Free text description of change. This can wrap to a`*\
`0 !HISTORY YYYY-MM-DD [`*`UserName`*`] `*`second row with the same date if necessary. However authors should lean toward writing longer`*\
`0 !HISTORY YYYY-MM-DD [`*`UserName`*`] `*`single !HISTORY lines(and not feel constrained to the historic 80-character limit on line length)`*` `\
or\
` 0 !HISTORY YYYY-MM-DD {`*`RealName`*`} `*`Free text description of change`*` `

`0 // Comments`

`1 <colour> x y z a b c d e f g h i <file>`

Where:

<span id="desc"></span>

#### `PartDescription`

<span id="gendesc"></span>

##### General

This the descriptive name of the part. If the description contains dimensions, the numbers will be in decimal format (as opposed to fractions) and a leading space should be added to single digit numbers to aid in sorting. Decimals should be limited to 2 decimal places\
Examples:\
`0 Brick  2 x  4`\
`0 Brick  1 x 10` (Note the lack of a leading space on the 2 digit number)\
`0 Brick  3.1 x  3.1`\
`0 Brick  3 x  3 x  0.34` (Note the 2 decimal places)

<span id="gendesc"></span>

##### Needs Work

If the part is good enough for public use, but has some deficiencies that need to be addressed, the text " (Needs Work)" (without the quotation marks) can be added to the end of the description. If the description includes "(Needs Work)", a comment must be added to the file immediately after the header that explains the work that needs to be done

<span id="descprefix"></span>

##### Special Prefix Characters

Some programs rely on the parts.lst file rather than the LDRAW_ORG meta-statement. Special prefix characters are added to the start of the part description to prevent the parts being included in the list by these programs:

- The descriptions of all subparts (i.e. line 4 = '0 !LDRAW_ORG Subpart') must start with '~'
- The description of all obsolete parts, maintained for backwards compatibility must start with '~'
- The use of '~' for non "s\\" part files is at the author's discretion, to hide mouldings that are not released independently. This is one case where merely reading the LDRAW_ORG line is insufficient for tools to know how to treat the file.
- The descriptions of all aliases (i.e. line 4 = '0 !LDRAW_ORG Part Alias') must start with '='
- The descriptions of all third party parts must start with '\|' or '~\|' (as appropriate)
- The descriptions of all physical colour parts (i.e. line 4 = '0 !LDRAW_ORG Part Physical_Colour') should start with '\_' (This usage is depreciated)

<span id="name"></span>

#### `Name`

`Filename` is the file name of the part including the folder (e.g. s/, 48/) if it is not directly in the parts or p folders.

<span id="author"></span>

#### `Author`

`RealName` is the author's real name.

`UserName` is the author's LDraw username. It is optional for those authors that had parts released prior to the establishment of the Parts Tracker and have not contributed since

<span id="ldraworg"></span>

#### `!LDRAW_ORG`

<span id="offpart"></span>

##### Official Parts

`Part| Subpart| Primitive| 8_Primitive| 48_Primitive| Shortcut` are used in Official Library Parts\
`YYYY-RR` is the LDraw update year and release within year.

<span id="unoffpart"></span>

##### Unofficial Parts

`Unofficial_Part| Unofficial_Subpart| Unofficial_Primitive| Unofficial_8_Primitive| Unofficial_48_Primitive| Unofficial_Shortcut` are used in unofficial parts on the Parts Tracker.

<span id="optqual"></span>

##### Optional Qualifiers

`(optional qualifier(s))` are one of the following:

- `Alias`\
  The purpose of the Alias qualifier is to identify a part which is visually identical to another (often caused by LEGO using two different numbers, one for opaque and one for transparent versions of the same part (e.g. 32061), but more recently, there have also been new part numbers for well-established parts - such as brick 2x6\
  An alias file will typically, but not necessarily, contain only one sub-file reference (line type 1) entry\
  A file with an Alias type qualifier must not refer to a file that itself has an Alias qualifier.
- `Physical_Colour`\
  This qualifier is depreciated and all parts that used it have been made obsolete.\
  The purpose of the Physical_Colour qualifier was to identify a part which is encoded as a specific colour of a part
- `Flexible_Section`\
  The purpose of the Flexible_Section qualifier is to identify a file in the "parts" folder which represents a subsection of a flexible part. The placement of such files in the "parts" folder allows LDraw users and LDraw applications (such as LSynth) to utilise the subsections to create a flexed rendition of the parent part. Ideally LDraw editing applications should use this qualifier to identify flexible part subsections.

<span id="ldraworg"></span>

#### `!LICENSE`

`CAreadme.txt` or `NonCAreadme.txt` is the <a href="http://creativecommons.org/licenses/by/2.0/" target="_blank" rel="noopener">human readable version of the CCAL</a> added to the parts library package. The `Redistributable under CCAL version 2.0` and `Not redistributable` versions of this meta are depreciated and no longer used.

<span id="opmeta"></span>

#### Optional Meta Commands

The following meta-commands are optional

- `!HELP` (Authors should constrain themselves to a 50-character limit to keep the text readable.)

- `!CMDLINE`

- `!PREVIEW <colour> x y z a b c d e f g h i`

  This META defines how a part's preview image (e.g. the image generated for the Library part detail page or in a BOM) color, position, and rotation should be modified from the standard view. The standard view is defined as the part's bounding box centered on the origin and the camera postioned at 30 lat, 45 long looking at the origin.

  `<colour> x y z a b c d e f g h i`\
  are the equivilent to the same definition as [type 1 line](https://www.ldraw.org/article/218.html#lt1). Colours are limited to the colour numbers of the colours defined in the LDConfig.ldr

  This META should not be included if the value is `16 0 0 0 1 0 0 0 1 0 0 0 1`

- `BFC`

  Note:

  A `0 BFC CERTIFY CCW` command is required for Official Library parts. For all other uses it is highly recommended to include this statement with a `NOCERTIFY` for non-BFC certified parts, but not required.

- `!KEYWORDS`

- `!CATEGORY`

  Note:

  This command required if the first word of the part description is not in the official category list: [LDraw.org CATEGORY and KEYWORDS Language Extension](https://www.ldraw.org/article/340). If !CATEGORY is set it must to be one of the listed categories.

<span id="Examples"></span>

### Examples

    0 Animal Scorpion
    0 Name: 30169.dat
    0 Author: Chris Dee [cwdee]
    0 !LDRAW_ORG Part UPDATE 2006-01
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt

    0 !HELP Obviously there is no need for additional
    0 !HELP information in this part. But it will give
    0 !HELP you an idea of a primitive formatting.
    0 !HELP
    0 !HELP We should limit the length of
    0 !HELP a line to 50 characters for the sake of readability.

    0 BFC CERTIFY CW

    0 !CATEGORY Animal
    0 !KEYWORDS Sting, Poison, Adventurers, Egypt
    0 !KEYWORDS Zodiac

    0 !CMDLINE -c1

    0 !HISTORY 2000-08-?? {Axel Poque} fixes to resolve L3P error messages
    0 !HISTORY 2000-08-?? {Manfred Moolhuysen} fixes to resolve L3P error messages,
    0 !HISTORY 2000-08-?? {Manfred Moolhuysen} fixed gap where body meets head
    0 !HISTORY 2002-04-25 [PTadmin] Official update 2002-02
    0 !HISTORY 2004-05-18 [guyvivan] Made BFC compliant
    0 !HISTORY 2004-05-18 [guyvivan] Used more primitives
    0 !HISTORY 2006-??-?? [PTadmin] Official update 2006-01

    0 // Tail
    1 16 1 0 23 1 0 0 0 1 0 0 0 1 4-4cyli.dat

or

    0 Boat Base 8 x 10
    0 Name: 2622.dat
    0 Author: Chris Alano
    0 !LDRAW_ORG Part UPDATE 2000-02
    0 !LICENSE Not redistributable : see NonCAreadme.txt

    0 BFC NOCERTIFY

    0 !KEYWORDS Pirates, Caribbean, Ship

    2 24 100 24 80 80 24 20

<span id="movedto"></span>

### Moved To Files

"~Moved to" files are created when part variants are created or the part real number for a "u" part is determined

<span id="movedsyntax"></span>

#### Syntax

` 0 ~Moved to <new_number>`\
`0 Name: <old_number>.dat`\
`0 Author: [PTadmin]`\
`0 !LDRAW_ORG <Part, Subpart, etc as appropriate> (optional qualifier(s)) UPDATE YYYY-RR`\
`0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt `

`0 BFC CERTIFY CCW`

`0 !HISTORY <date> [PTAdmin] <any necessary comment(s)>`

` 0 // <part_description>`\
`1 16 0 0 0 1 0 0 0 1 0 0 0 1 <new_number>.dat`\
`0 `

<span id="movedex"></span>

#### Example

    0 ~Moved to 3842a
    0 Name: 193a.dat
    0 Author: [PTadmin]
    0 !LDRAW_ORG Part UPDATE 2006-01
    0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt

    0 BFC CERTIFY CCW

    0 !HISTORY 2006-12-31 [PTadmin] Official update 2006-01

    0 // Minifig Helmet Classic with Thin Chin Guard
    1 16 0 0 0 1 0 0 0 1 0 0 0 1 3842a.dat
    0

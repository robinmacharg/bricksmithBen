<!-- Source: https://www.ldraw.org/article/593.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Official Model Repository (OMR) Specification

**Maintained by:** LDraw.org Administration Team\
**Revision:** 17-Dec-2020

**Revision History:**\
17-Dec-2020: Initial\
22-Nov-2023: Update license requirements

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="intro"></span>

### Introduction

The Official Model Repository (OMR) is a database of files in the LDraw File Format describing models that are released as sets by LEGO®.

For consistency between models and ease of indexing by software, a standard for the file headers, names, and hierarchy in the OMR is needed. This document will outline the extra requirements (in addition to those set forth in the [LDraw File Format](https://www.ldraw.org/article/218) specification) for a model to be included in the OMR.

These requirements should be considered guidelines to be followed in most situations. Models that do not completely conform to this specification can still be included in the OMR at the discretion of the LDraw.org Administation Team

<span id="base_requirements"></span>

### Base Requirements

All files in the model will conform to the current [LDraw File Format](https://www.ldraw.org/article/218).

<span id="base_file_naming"></span>

#### Base File Naming

Each model in the OMR will consist of several files that are packaged together into a single MPD file. For sets that include instructions for multiple models, each model will have its own MPD file.

For playsets or other sets where there are multiple models that are part of an integral whole, all of the submodels will be contained in one MPD. For example: the set 10267 - Gingerbread House has many different loose models in the instructions. All of these models should be included in the same MPD and arraged in a master scene.

Each MPD for the set will be named in the following manner:

`<Set Number>[-<Qualifier Number>] - <Set Name>[ - <Sub Model Name>]`

Where:

`<Set Number>`: The number assigned on the container of the set.

`-<Qualifier Number>`: Is a sequential number, starting with 1. The qualifier of "-1" is optional and gets added only if there is more than one set that could be assigned the same `<Set Number>`. The first set using a given number would be understood to never contain the qualifier however numbering should start with the oldest set and some investigation should be done in existing set databases. All subsequent numbers are required.\
Example:\
`6901 - Mobile Lab.mpd (Produced in 1980)`\
`6901-2 - Space Plane.mpd (Produced in 1998)`

`<Set Name>`: The name of the set printed on the container in English.

`<Sub Model Name>`: This is optional in most cases. This is required for alternate models that are detailed in instructions (e.g. the Creator theme). In this case the naming is left to the discretion of the author but should be descriptive of the model contained in the MPD.

<span id="meta_commands"></span>

#### META commands

All META commands are allowed in the model file but not specifically required except as specified for the header. If included, any META commands used should enable any instructions generated to be as close to the official instructions as possible.

<span id="mirrored_geometry"></span>

#### Mirrored geometry

Models with bilaterally symmetric sections can often be modeled much more easily by modeling one half of the symmetric section and then including it in the model twice, with one instance mirrored around the symmetry line. Unfortunately, this mirroring produces an incorrect parts list, and also produces a mirrored LEGO logo on the model's studs when rendered with certain software, so using mirroring is strongly discouraged.

<span id="mpd_file_structure"></span>

### MPD File Structure

The MPD file will conform to the [MPD File Specification](https://www.ldraw.org/article/47).

<span id="normal"></span>

#### Regular files and subfiles

The filename of each file in the MPD will have the following structure:

`<Set Number>[-<Qualifier Number>] - <Individual filename>`

Where:

`<Set Number>` and `-<Qualifier Number>` are described above and should match the parent MPD file name.

`<Individual filename>` is up to the discretion of the author with the following guidance:

- A logical naming scheme is highly desired.
- Each individual model in the set (e.g. a vehicle or minifig) shall have its own separate file inside the MPD.
- Minifig file name should have the name of the character, if known.

<span id="unoff"></span>

#### Unofficial Parts

Unofficial parts are allowed to be used but must be included in the MPD as referenced subfiles. The filename of the unofficial part is subject to the same naming rules as outlined above execept that `<Individual filename>` will be the part number of the unoffical part as it appears in the refferring type 1 line\
Example\
`33956.dat` would be renamed to `3345 - 33956.dat` or `3345-1 - 33956.dat`.

It is highly encouraged that any parts created for use in an OMR file be submitted to the LDraw.org Parts Tracker.

<span id="unavail"></span>

#### Unavailable Parts

If a part is unavailable either officially or on the LDraw.org Parts Tracker, a suitable substitution may be made. If the unavailable part is a patterned part with an unpatterned version available, use the unpatterned version.

If a substituion or ommission is made a comment stating such is desired, but not required. Reference the step and page number of the instructions for clarity, if needed

Examples:\
`0 // The next piece should have the Star Wars Hatch pattern, Bricklink Number XXXX`\
`0 // Bionicle piece X should go here per step Y on page Z`

<span id="file_headers"></span>

### File Headers

Each individual model file in the MPD that does not represent an unofficial part must have the following standard header format.

Each individual model file in the MPD that represents an unofficial part must use the standard header format of unofficial parts on the parts tracker. Its 0 FILE entry will reflect the modified MPD version of the part's filename, but the rest of the header will reflect the original filename.

Standard Header:

    0 FILE <Filename>.ldr
    0 <Individual filename>
    0 Name: <Filename>.ldr
    0 Author: <Author Name> [Username]
    0 !LDRAW_ORG Model -OR- 0 !LDRAW_ORG Unofficial_Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    0 !THEME Theme name
    0 !KEYWORDS words, more words, …,
    0 !KEYWORDS words in second row, …, final words

    0 !HISTORY YYYY-MM-DD [Username] Free text description of change. This can wrap to a
    0 !HISTORY YYYY-MM-DD [Username] second row with the same date if necessary. However authors should lean toward writing longer
    0 !HISTORY YYYY-MM-DD [Username] single !HISTORY lines(and not feel constrained to the historic 80-character limit on line length).

Where:

`<Filename>` and `<Individual filename>` are as descibed above

`!THEME` is the LEGO branded theme of the set. Where possible try to match this with other inventory website.

All other meta commands are described in [Official Library Header Specification](https://www.ldraw.org/article/398.html)

The commands are `!THEME`, `!KEYWORDS`, and `!HISTORY` are optional

Example:

    0 FILE 4896 - Roadster Main.ldr
    0 Roadster Main
    0 Name: 4896 - Roadster Main.ldr
    0 Author: Joe Smith [jsmith]
    0 !LDRAW_ORG Unofficial_Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    0 !THEME Creator
    0 !KEYWORDS car, convertible

    0 !HISTORY 2011-08-01 [jsmith] Initial creation

<span id="omr_example"></span>

### OMR Example

    0 FILE 6712 - Main.ldr
    0 Main
    0 Name: 6712 - Main.ldr
    0 Author: Willy Tschager [Holly-Wood]
    0 !LDRAW_ORG Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    1 0 0 0 0 1 0 0 0 1 0 0 0 1 6712 - Fireplace.ldr
    1 0 -140 -49 -32 0.5 0 -0.866 0 1 0 0.866 0 0.5 6712 - Horse.ldr
    1 0 -140.866 -129 -31.5 0.5 0 -0.866 0 1 0 0.866 0 0.5 6712 - Sheriff.ldr
    1 0 83 -99 64 1 0 0 0 1 0 0 0 1 6712 - Bandit.ldr
    1 6 81 3 76 1 0 0 0 1 0 0 0 1 30139.dat
    1 2 -51 8 86 1 0 0 0 1 0 0 0 1 6064.dat
    1 7 80 0 -14 0.707 0 0.707 0 1 0 -0.707 0 0.707 3069bp03.dat

    0 FILE 6712 - Horse.ldr
    0 Horse
    0 Name: 6712 - Horse.ldr
    0 Author: Willy Tschager [Holly-Wood]
    0 !LDRAW_ORG Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    1 0 0 0 0 1 0 0 0 1 0 0 0 1 4493c01.dat
    1 6 0 -8 0 1 0 0 0 1 0 0 0 1 4491b.dat
    1 7 -31 -44 27 1 0 0 0 0 -1 0 1 0 30141.dat

    0 FILE 6712 - Fireplace.ldr
    0 Fireplace
    0 Name: 6712 - Fireplace.ldr
    0 Author: Willy Tschager [Holly-Wood]
    0 !LDRAW_ORG Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    1 7 0 0 0 1 0 0 0 1 0 0 0 1 3031.dat
    0 STEP
    1 0 -30 -8 10 0 0 -1 0 1 0 1 0 0 2555.dat
    1 0 -30 -8 -10 0 0 -1 0 1 0 1 0 0 2555.dat
    0 STEP
    1 0 0 -8 -10 1 0 0 0 1 0 0 0 1 2412b.dat
    1 0 0 -8 10 1 0 0 0 1 0 0 0 1 2412b.dat
    0 STEP
    1 38 -24 -14 -10 0 0 1 0 -1 0 1 0 0 6126a.dat
    1 38 -24 -14 10 0 0 1 0 -1 0 1 0 0 6126a.dat
    1 0 0 -28 -2 -0.966 0 0.259 0 1 0 -0.259 0 -0.966 4528.dat

    0 FILE 6712 - Sheriff.ldr
    0 Sheriff
    0 Name: 6712 - Sheriff.ldr
    0 Author: Willy Tschager [Holly-Wood]
    0 !LDRAW_ORG Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    1 7 0 -24 0 1 0 0 0 1 0 0 0 1 3629pw2.dat
    1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3626bp35.dat
    1 7 0 0 0 1 0 0 0 1 0 0 0 1 973pw4.dat
    1 0 0 32 0 1 0 0 0 1 0 0 0 1 3815.dat
    1 7 -15.552 9 0 0.985 -0.128 -0.112 0.17 0.743 0.646 0 -0.656 0.755 3818.dat
    1 7 15.552 9 0 0.985 0.139 0.098 -0.17 0.807 0.565 0 -0.574 0.819 3819.dat
    1 0 -21.93 15.393 -20.098 0.995 -0.066 0.069 0.066 0.997 0.007 -0.07 -0.002 0.997 3820.dat
    1 0 22.28 17.422 -19.215 0.985 0.167 -0.03 -0.17 0.97 -0.171 0 0.174 0.985 3820.dat
    1 0 0 44 0 1 0 0 0 1 0 0 0 1 3816.dat
    1 0 0 44 0 1 0 0 0 1 0 0 0 1 3817.dat
    1 7 -22.656 13.187 -30.096 0.998 -0.052 0.033 0.058 0.975 -0.213 -0.021 0.214 0.976 30132.dat

    0 FILE 6712 - Bandit.ldr
    0 Bandit
    0 Name: 6712 - Bandit.ldr
    0 Author: Willy Tschager [Holly-Wood]
    0 !LDRAW_ORG Model
    0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt

    1 6 0 -27 0 1 0 0 0 1 0 0 0 1 3629.dat
    1 14 0 -27 0 1 0 0 0 1 0 0 0 1 3626bpw1.dat
    1 0 0 0 0 -1 0 0 0 1 0 0 0 -1 30133.dat
    1 0 0 0 0 1 0 0 0 1 0 0 0 1 973pw5.dat
    1 0 0 32 0 1 0 0 0 1 0 0 0 1 3815.dat
    1 0 -15.552 9 0 0.985 -0.128 -0.112 0.17 0.743 0.646 0 -0.656 0.755 3818.dat
    1 0 15.552 9 0 0.985 0.139 0.098 -0.17 0.807 0.565 0 -0.574 0.819 3819.dat
    1 0 -21.93 15.393 -20.098 0.135 0.99 0.012 -0.988 0.136 -0.069 -0.07 -0.002 0.997 3820.dat
    1 0 22.28 17.422 -19.215 0.985 0.167 -0.03 -0.17 0.97 -0.171 0 0.174 0.985 3820.dat
    1 7 22.08 16.263 -29.297 0.985 0.155 -0.069 -0.17 0.899 -0.401 0 0.407 0.913 30132.dat
    1 0 0 44 0 1 0 0 0 1 0 0 0 1 3816.dat
    1 0 0 44 0 1 0 0 0 1 0 0 0 1 3817.dat
    1 2 -18 13 -47 0.259 -0.118 0.959 0 0.993 0.122 -0.966 -0.032 0.257 3069bpw2.dat

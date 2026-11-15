<!-- Source: https://www.ldraw.org/article/512.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# LDraw.org Official Parts Library Specifications

**Maintained by:** LDraw.org Library Administrator\
**Revision:** 2.4 (03-Feb-2023)

**Revision History:**

1 - Original\
2 - Reorganized and consolidated other sources into this document\
2.1 - Clarified requirements for TEXMAP geometry and fallback\
2.2 - Added NOCLIP and !KEYWORDS requirements for stickers\
2.3 - Clarified description requirements for patterns on mold variants parts

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="intro"></span>

### Introduction

This document describes additional specifications for parts to be included in the LDraw.org Official Parts Library (Official Library). Unless specifically contradicted by this document all requirements within the [LDraw File Format 1.0.2 specification](https://www.ldraw.org/article/218) also apply to part files within the Official Library.

These rules have evolved over time, and there may be files in the Official Library that do not conform to these rules. Legacy parts should not be edited solely for the purpose of making them conform. However, if the part is changed and submitted to the Parts Tracker for any other reason, non-conformant lines must be updated.

<span id="filenaming"></span>

### General File Naming

<span id="file_name_limit"></span>

#### File Name Limitations

Filenames must not be longer than 25 characters (including the extension) and must only contain the following characters:\
`a-z, 0-9, _,-`\
(To avoid confusion with English grammar, comma is not a permitted character.)\
Note: The file format specification states that filenames are case-insensitive. However, all official parts will be issued with lower-case only names.

<span id="extension"></span>

#### Extension

All part files in the LDraw Parts Library are required to carry the `.dat` extension.

<span id="part_numbering"></span>

#### Part Numbering

Part numbers for official parts must conform to the [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html)

<span id="texturename"></span>

#### Texture Image Files

See [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html#texture) for texture image file name rules.

The encoding format of texture images is specified as PNG. Therefore texture images will have an extension of `.png`

<span id="file_content"></span>

### General File Content

<span id="numbers"></span>

#### Numbers

<span id="precision"></span>

##### Precision

In general, three decimal places are sufficient for parts, subparts, and primitives representing portions of parts that are not intended to be scaled (for example, studs, pegs, peg-holes, clips, hinge ends, etc.). Four decimal places should be used for high-res primitives and any primitives designed to be scaled (for example, cylinder sections, boxes, rectangles, discs, edges, etc.) as this allows such primitives to be scaled by a factor of ten while still preserving three decimal places of accuracy. The [primitives reference](https://www.ldraw.org/library/primref/) indicates which primitive families are not supposed to be scaled.

In all cases decimal precision should not exceed 5 decimal places.

<span id="format"></span>

##### Format

Trailing zeros must be removed (i.e. 1.5, not 1.500 or 1, not 1.0). Leading zeros unless immediately before the decimal point must be removed (i.e. 1.5, not 01.5). The leading zero before the decimal point is optional (i.e. 0.5 and .5 are both valid).

<span id="geometry"></span>

#### Geometry

<span id="matrix"></span>

##### Matrix restrictions

The matrix specified for sub-files (line type 1) must not be singular nor contain columns or rows of all zeros.

<span id="coplanar"></span>

##### Co-planar/Co-linear Tolerance and Concave Quads

Quads and triangles with co-linear vertices, quads with non-co-planer vertices, and concave quads are disallowed per the LDraw File Format. However, the tolerances for this co-linearity, co-planarity are not defined.

To prevent co-linear vertices in quads/triangles and concave quads, every interior angle in a quad or triangle must not be greater than 179.9 degrees or smaller than 0.025 degrees. Concave quads must be split into two triangles.

A quad is considered co-planar if it is split into two triangles and both triangles are co-planar with each other. There are two ways to split a quad into two triangles, and both must result in co-planar triangles. The triangles are considered co-planar if the angle between their surface normals is less than or equal to 3 degrees. However, an angle of less than 1 degree is required unless justification is given by the part author. This is especially true for large quads where the "warp" can be seen at normal viewing magnifications.

<span id="overlaps"></span>

##### Overlapping and Intersecting Line Types

All or part of a line (line type 2) may not overlap all or part of any other line (line type 2).

All or part of a conditional line (line type 5) may not overlap all or part of any other conditional line (line type 5), with the exception of complementary conditional lines for curved primitives. Complementary conditional lines are placed at the end of curved primitives where those curved primitives may join with either a continuation of the curve, or with other geometry. In this case, the control points that are off of the edge of the curved primitive are placed so they are tangent to the curve.

If two such curves are placed next to each other (for example to turn a quarter cylinder into a half cylinder), the conditional lines on the edge of each primitive will overlap exactly, and their control points will complement each other such that at most one will be rendered at any given time, and one of the two will always be rendered when appropriate. When other geometry is placed against such a curved primitive, nothing needs to be done if the geometry is tangent to the curve. If it is sloped further, then a complementary conditional line will be placed on the edge of that geometry, with the control points past the edge of the geometry configured to be tangent to the curve, and the two end points of the conditional placed to exactly overlap the complementary conditional line on the edge of the curved primitive.

Example:

The first and last conditional lines in a cyli primitive have a control point that is tangent to the cylinder. When two such cyli primitives join, the two conditional lines complement each other, like so:

<img src="https://www.ldraw.org/uploads/images/Articles/Control_points_of_two_primitives.png" width="278" height="250" alt="Control points of two primitives" />

This shows the extra complementary conditional line an author has to add if a surface is not placed in the tangential plane.

<img src="https://www.ldraw.org/uploads/images/Articles/Control_points_of_a_primitive_and_face.png" width="278" height="280" alt="Control points of a primitive and face" />

Part (but not all) of a conditional line (line type 5) may overlap all (but not part) of a line (line type 2). Consider the line A-B-C-D

<img src="https://www.ldraw.org/uploads/images/Articles/Overlapping_conditional_lines.PNG" width="700" height="160" alt="Overlapping conditional lines" />

- If AB and CD need to be conditional lines and BC a line, it is acceptable to define this as a line BC and a single conditional line AD
- If AC needs to be a line and just CD needs to be a conditional line, it is **not** acceptable to define the conditional line as either AD or BD
- If AD is a line, there are no valid conditional lines along the length of AD

Lines (line type 2 or 5) may intersect any other line (line type 2 or 5).

Every effort must be made to remove overlapping co-planar polygons (line type 3 or 4). Where overlapping polygons are unavoidable, the overlap must be kept to the absolute minimum.

Every effort must be made to remove intersecting (non co-planar) polygons (line type 3 or 4). Where intersecting polygons are unavoidable, the intersection(s) must be kept to the absolute minimum.

Note: Primitives that overlap/intersect other primitives or polygons (line type 3 or 4), provided that the overlap is small, are considered acceptable. The intention is **not** to force part authors to in-line primitives. However, there may be some cases where it is better to use (say) a 3-8cyli and a quad than a 1-2cyli; case-by-case decisions are left to the parts review process.

<span id="origin"></span>

##### Orientation/Origin

In general, parts that have studs should be oriented such that the top studs point up (-y) and the bottom tubes point down (+y).

For parts with studs, the origin of the parts will be the centered on the top most stud group. The bottom of studs should lie on the x-z plane (i.e. the bottom of the studs should be at y=0)

For hinge or hinge like parts, the origin should be at the rotation point

These rules are generic. Look at other similar parts if it is unclear and if uncentainty reamins, ask. If some other orientation/origin makes sense, the reasoning should be made when the part is submitted to the Parts Tracker.

<span id="studorient"></span>

##### Stud Orientation

The individual studs on a part should be rotated such that the stud logo appears is it would on the real part. Since the generic stud.dat does not show a logo, rotation should be checked by using a LDraw program designed to show logo.

Subparts that use studs should not be mirrored as this would cause the logo to appear mirrored. In this case, the studs can be moved from the subfile to the parent file which will avoid mirroring but still allow reuse of symmetrical geometry.

<span id="duplicates"></span>

##### Duplicate Line Types

Identical line type 1-5 lines are not permitted.

The ordering of the vertex points in lines, quads, triangles, and conditional lines (line types 2-5) are not considered when checking for identical lines. The control points are not considered when checking for identical conditional lines (line type 5).

<span id="colours"></span>

##### Colour restrictions

Polygons (line types 3 and 4) shall not use colour 24.

Lines (line types 2 and 5) must use colour 24.

All colour numbers used in part files **must** be present in LDConfig.ldr, with the exception of pattern/sticker geometry, which may use Direct Colours (see [LDraw File Format Spec](https://www.ldraw.org/article/218/#colours)).

LDConfig.ldr will only contain colours that have at some point in time been used by LEGO as the non-painted colour of materials used in LEGO-branded toys, plus ldraw.exe's special colour codes 16 and 24. This includes materials such as the metal track for 9V train tracks, but does not include the colours of paint used to decorate parts or ink used on stickers.

In general, metallic colours on stickers, patterned parts, and other printed materials should use the LDraw Metallic Colours and not Chrome or Pearl colours. There are exceptions that will be handled on a case by case basis.

<span id="meta"></span>

#### META Commands

<span id="metaheader"></span>

##### Header Meta Commands

Official parts must conform to the [Official Library Header Specification](https://www.ldraw.org/article/398).

<span id="metabody"></span>

##### Body Meta Commands

Only the following meta commands are permitted in the body of official parts:

- 0 // style comments
- All meta commands specified in [Language Extension for Back Face Culling (BFC)](https://www.ldraw.org/article/415.html)
- All meta commands specified in [Texture Mapping (!TEXMAP) Language Extension](https://www.ldraw.org/texmap-spec.html)

<span id="bfc"></span>

##### Back Face Culling (BFC)

All official parts will contain `0 BFC CERTIFY CCW` and have valid quad/triangle winding to support this. See [Language Extension for Back Face Culling (BFC)](https://www.ldraw.org/article/415.html) for reference.

<span id="texmapgeneral"></span>

##### !TEXMAP

Sufficient !TEXMAP \<geometry2\> and/or \<geometry3\> lines (as outlined in the [Texture Mapping (!TEXMAP) Language Extension](https://www.ldraw.org/texmap-spec.html)) must be included such that the part renders correctly in non-!TEXMAP supporting programs. It is highly encouraged that the included geometry reflect the pattern created by the !TEXMAP (even if it is reduced in resolution or colors) but this is not required.

<span id="generated"></span>

##### Generated File Meta Commands

Meta commands used by programs to generate file geometry may be left in the part file provided they are correctly commented out. It is desirable to add a comment to mark the end of the generated section.

<span id="shortcuts"></span>

### Shortcut Part Regulations

<span id="shortcut_num"></span>

#### Shortcut Part Numbering

See [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html#shortcut) for shortcut part number rules.

<span id="shortcut_other"></span>

#### General Rules for Shortcuts

Shortcut files are used when several separate parts are typically delivered from LEGO pre-assembled or are frequently used in combination.

Shortcuts are typically made of the unpatterned (or plain) version of an assembly. Shortcuts of patterned assemblies will only be considered on a case by case basis. Assemblies that do not conform to this rule can remain in the library and not be made obsolete.

When parts are used in assemblies (provided as such by LEGO and impossible to separate in normal use) their description begins with ~ so they don't appear in part selection lists. LDraw users should use the assembly shortcuts instead.

To further clarify:

- For assemblies without moving parts, it's simple: all parts composing the assembly are ~ and an assembly shortcut is provided. Several shortcuts may be needed to account for different colour combinations.\
  Example:\
  NXT light sensor 55969 shortcut, composed of ~ parts 54732, 55972, 55816, 55970, 55966.
- For assemblies with moving parts, a shortcut should be provided for each mechanical entity. This way the LDraw user can compose their own assembly in any position. An overall assembly is provided as well, to simplify user life when default position is usable, and for bill of materials usage. Different positional forms of the same combination of parts should use an additional -fN suffix to distinguish them.\
  Example:\
  NXT motor has a case assembly 54715c01 and an axle hub assembly 54725c01. Case assembly 54715c01 is made of ~parts 54714, 54715, 54716, 54717 and 54732. Hub assembly 54725c01 is made of two 54725 ~parts. Complete motor assembly 53787 is made of 54715c01 + 54725c01.
- In case one of the moving assemblies is reduced to a single part (eg. axle hub of PF motors), the description of this part is not tilded, so that the user can pick it easily to create his own position combination. For example, the small linear actuator has 3 sections moving independently:
  - the body, assembly 92693c01, composed of ~parts 92693 and 92697.
  - the rotating axle, single part not tilded 92695.
  - the piston, single part not tilded 92696.

  Two complete assemblies are provided, contracted, and extended (92693c01-f1 and 92693c01-f2).

<span id="flexible_parts"></span>

#### Flexible Parts

Flexible parts are parts that are made out of a non-rigid material and are intended by LEGO to deform. Examples include hoses, ropes, strings, springs, fabrics, rubber bands, and plastic sheets

These parts are typically modelled as a series of discrete part pieces that are then "formed" to simulate curvature. This places them in the shortcut category, and their descriptions will follow the rules outlined for shortcuts (i.e. use of the "~" character).

Flexible parts are always modelled in their flat or at rest state as the primary version. Subsequent formed versions shall have a suffix added to the part number as specified in the [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html#shortcut_mov).

<span id="stickers"></span>

### Sticker Parts Regulations

<span id="sticker_num"></span>

#### Sticker Numbering

See [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html#sticker) for sticker number rules

<span id="sticker_desc"></span>

#### Sticker Description

The description of the part should begin with 'Sticker ...' followed by the dimensions if rectangular or round, or a description of the shape, and then a description of the sticker. The description should not end with 'Pattern'.

Dimensions should be specified in studs (where 1 stud = 20 LDraw units) and as \[z-dimension\] x \[x-dimension\]. Additional rules regarding dimension numbers are contained in the [Official Library Header Specification](https://www.ldraw.org/article/398)

Examples:\
`Sticker  2.6 x  5.5 ...`\
`Sticker  3.1 x  3.1 Round ...`\
`Sticker Minifig Torso ...`\
`Sticker Minifig Shield Triangular ...`

<span id="sticker_keywords"></span>

#### Sticker !KEYWORDS Entry

All stickers and sticker shortcuts should, at a minimum, include at least one !KEYWORDS entry in the form of `Set <set number>` where `<set number>` is the number of an official LEGO set in which that pattern appears. Only one set need be listed but more can be if desired.

<span id="sticker_geo"></span>

#### Sticker Geometry

Stickers should be created flat. If the sticker is designed to be placed on the curved surface of a part or folded around the edge of a part, a 'formed' version of the sticker part may be modelled in addition to the flat version.

The sticker should be modelled as a 0.25 LDU thin box (or whatever shape sticker is in), without any edge lines (type 2 lines), and coloured with main colour 16. The sticker should be oriented such that the top face is at -0.25 Y and parallel with the X-Z plane. The pattern with the hardcoded colours is on the top face.

The origin of a formed sticker part may match that of the part for which it is intended or be noted in a !HELP header line.

The sticker pattern is modelled in its true colours; they are not modifiable from the outside. All colours of the top surface must be matched. The back side and sides of the sticker must use colour 16. Print on a transparent plastic sticker sheet should use colour 16 on the transparent part of the top surface.

For stickers printed on a transparent medium, the type 1, 3, and 4 lines that comprise the pattern shall be preceded by a 0 BFC NOCLIP statement. If there is non-pattern geometry after the pattern geometry, the pattern geometry shall be ended by a 0 BFC CLIP statement.

Conditional lines (type 5 lines), in colour 24, should be provided around curved edges and on the curved surface of formed sticker parts. Solid edges (type 2 lines) are also allowed for folds in formed sticker parts, but not around the edges of the sticker.

<span id="sticker_orientation"></span>

#### Sticker Orientation

Sticker patterns should be oriented so that top is aligned with +Z axis.

Top is defined as either the logical top of a picture, text, etc. or, in the case of more abstract patterns, what the top is when the sticker is applied.

When in doubt, sticker should be oriented such that X value is greater that Z (Landscape).

<img src="https://www.ldraw.org/uploads/images/Articles/sticker_orientation.png" width="499" height="305" alt="Sticker Orientation" />

<span id="sticker_back"></span>

#### Sticker Backing Boxes

The backing box is defined as the sides and bottom surface of the sticker

See the [LDraw.org Library Sticker Box Standard](https://www.ldraw.org/docs-main/ldraw-org-official-library-standards/sticker-box-standard.html)

<span id="sticker_shortcuts"></span>

#### Sticker Shortcuts

Shortcuts that consist of one part (which may be a composite part) and one or more stickers are allowed in the official library.

See [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html#sticker_shortcut) for sticker shortcut part number rules.

Additionally:

- The shortcut may not include more than one part, although that part may be a shortcut part.
- The sticker(s) must be applied in the same location(s) as shown in the instructions for the official LEGO model from which the sticker(s) originate(s).

<span id="patterns"></span>

### Patterned Part Regulations

<span id="pattern_num"></span>

#### Patterned Part Numbering

See [Official Library Part Number Specification](https://www.ldraw.org/part-number-spec.html#pattern) for patterned part number rules.

<span id="pattern_gen"></span>

#### Pattern Part General Rules

Patterned parts are considered both parts with printing on the plastic and parts that are moulded with multiple plastic colors

Some patterned parts have never been issued as plain, unpatterned parts by LEGO. Since this printing is easily removed, and LDraw parts can come in any variety, all patterned parts should be based on another plain, unpatterned part in the library. This means that a plain version of the patterned part should be created even if a plain version has never been produced by LEGO.

<span id="pattern_desc"></span>

#### Pattern Description

The description of a patterned part should in the following format:\
`<base part description> with <pattern description> Pattern`

Where:

- `<base part description>` is the description of the non-patterned version of the part. Note: For parts with mould variants (e.g. tiles with or without groove), the additional qualifier for the mould is only required if the same pattern is printed on more than one variation. Example: "Minifig Head with Solid Stud with ... Pattern" can be shortened to "Minifig Head with ... Pattern" if the patterned being modeled only appears on the "Solid Stud" variation.
- `<pattern description>` is a reasonably detailed description of the pattern. If unsure, use of the description on other inventory websites is encouraged.

<span id="pattern_key"></span>

#### Pattern !KEYWORDS Entry

A patterned part should, at a minimum, include at least one !KEYWORDS entry in the form of `Set <set number>` where `<set number>` is the number of an official LEGO set in which that pattern appears. Only one set need be listed but more can be if desired.

It is encouraged, but not required, that a cross reference number from an external inventory website (e.g. Bricklink, Rebrickable, BrickSet, etc.) be included in the !KEYWORDS. In this case the entry should be `<website name> <part number on website>` where `<website name>` is the name of the website and `<part number on website>` is that specific website's number for the pattern part (example: Bricklink 973pb0042).

Example:

    0 !KEYWORDS Set 10442, Bricklink 973pb0042

Errors in either one of these !KEYWORDS entries should not be cause for a hold vote on the Parts Tracker since this is simply data to make locating specific patterns easier.

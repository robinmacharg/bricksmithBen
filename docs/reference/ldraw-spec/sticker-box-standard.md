<!-- Source: https://www.ldraw.org/docs-main/ldraw-org-official-library-standards/sticker-box-standard.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# LDraw.org Library Sticker Box Standard

**Maintained by:** LDraw.org Library Administrators\
**Revision:** 22-Jul-2025

**Revision History:**\
22-Jul-2025: Original 2-Aug-2025: Reformatted for clarity. Specified orientation and naming for non-square/rectangular boxes.

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

## Sticker backing boxes

The backing box is defined as the sides and bottom surface of the sticker

For most stickers, the surface of the sticker is intended to be applied to an entire face of a single part. In this case, the size of the sticker should be that the edge of the sticker is 2 ldu from the edge of the part face. If actual, measured sticker size is +/- 1 ldu from this standard then the sticker should be modeled to the standard. Exceptions to this rule will be handled on a case by case basis and should be specifically addressed by the author upon submission.

### Flat Sticker Backs

The backing boxes for older, sharp cornered stickers should be modeled with an appropriately scaled box5-12.

Circular and oval shaped stickers should use an appropriately scaled 4-4cylc3

Stickers with irregular shapes should use quads and triangles with conditional lines where appropriate.

Newer stickers have rounded instead of sharp cut corners. The radius of standard rounded corners will be 1.5 LDU.

### Sticker Backs Files

A sticker back file is required for all square/rectangluar with standard rounded corners. Sticker back files are optional for all other sticker shapes but encouraged if that shape and size is commonly reused.

All sticker back files shall be oriented such that the X width is greater with than the Z width (landscape format).

Sticker back files will be of the !LDRAW_ORG type of Subpart and will located in the parts/s/ directory.

Flat sticker back files shall use the follow naming convention:

`stickerback<ZZZ>x<XXX><optional suffix a-z>.dat`

Where:

\<ZZZ\> and \<XXX\> are a 3 digit numbers representing the Z width (for ZZZ) and X width (for XXX) of the sticker. The value of this number is LDU/20 rounded to the nearest tenth. A leading zeros will be added for a number less than 10. Example: if the Z width of the sticker is 143 ldu, ZZZ is 072.

Sticker back files without the optional suffix are reserved for the square/rectangluar sticker backs with standard rounded corners. Sticker backs of any other shape with the same dimensions shall use an optional suffix \<a-z\>.

### Formed Sticker Backs

Orientation and origin of formed sticker backs shall follow the LDraw.org Official Parts Library Specifications for formed stickers.

Formed sticker back files should be created as reuse dictates.

Formed sticker backs shall use the follow naming convention:

`<part number>bNN.dat`

Where:

\<part number\> is the number of the part to which the sticker is formed NN is a 2 digit number with leading zeros starting at 01

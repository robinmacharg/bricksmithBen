<!-- Source: https://www.ldraw.org/article/299.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Colour Definition (!COLOUR) Language Extension

**Maintained by:** LDraw.org Standards Board\
**Revision:** 01-Apr-2025

**Revision History:**\
31-Apr-2009 - Original Document\
01-Arr-2025 - Added FABRIC material

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="spec"></span>

### Purpose

This meta-statement will specify the properties of a single LDraw colour code. This statement may appear at any time in an LDR file, but will probably be most useful in the file header.

In official LDraw.org materials, !COLOUR will appear in the ldconfig.ldr configuration file, to define the standard LDraw color set. It will not appear in any official part or primitive files.

The current version of ldconfig.ldr is distributed with the [Official Library](https://library.ldraw.org/updates?latest)

The ldconfig.ldr file that contains the standard colour definitions will contain the following in its header:

`0 !LDRAW_ORG Configuration UPDATE YYYY-MM-DD`

<span id="scope"></span>

### Scope

It's recommended that colour definitions be limited in scope. A color definition will affect colors from the point it first appears, continuing through the end of the file. Commands preceding a colour definition will not be affected by the definition. Color definitions will expire at the end of the file in which they appear, effectively falling out of scope. Color definitions will be passed to subfiles.

The configuration file, ldconfig.ldr, is not affected by the scoping rules, in the sense that the definitions in ldconfig.ldr remain in effect after the renderer is finished processing ldconfig.ldr.

<span id="syntax"></span>

### Syntax

The entire statement must appear on one line. It may be line-wrapped in this document for clarity.

`0 !COLOUR name CODE x VALUE v EDGE e [ALPHA a] [LUMINANCE l] [ CHROME | PEARLESCENT | RUBBER | MATTE_METALLIC | METAL | MATERIAL <params> ]`

Tags. CODE, VALUE, EDGE, ALPHA, DITHER, LUMINANCE, CHROME, PEARLESCENT, RUBBER, MATTE_METALLIC, METAL and MATERIAL are keyword tags. Some tags are followed by a single parameter value. Tags are case-insensitive. Numeric parameters, other than RGB color values, should be specified in decimal. RGB values must be specified in hexidecimal, and must be prefixed with \# or 0x. Byte values are integers in the range 0-255.\
Identifiers are strings of text. The allowable characters are alphanumerics from 7-bit ASCII set: a-zA-Z0-9\_. Additionally, the first character in an identifier must an alphabetic (a-zA-Z). Identifiers are case-insensitive.

<span id="parameters"></span>

### Definitions of Parameters

<span id="name"></span>

#### name

`name` - A short name for the color. Name may be any identifier. This item is provided mainly for human recognition. Name is a required element.

<span id="code"></span>

#### CODE x

`CODE x` - The LDraw color code. For LDraw compatibility, x is an integer 0-511. If strict LDraw compatibility is not required, x is any identifier recognized by a rendering program as a color code. Code is a required element.

<span id="value"></span>

#### VALUE v

`VALUE v` - The color value. v is a 24-bit RGB value. VALUE is a required element.

<span id="edge"></span>

#### EDGE e

`EDGE e` - The contrasting edge color. e may be either a color code or an RGB value. EDGE is a required element.

<span id="alpha"></span>

#### ALPHA a

`ALPHA a` - The alpha channel (transparency) value. a is a byte value, where 0 is totally colorless and 255 is completely opaque. In official materials, standard transparent colors will specify ALPHA 128. A 0 value is useful for temporarily hiding sections of models. ALPHA is an optional element.

<span id="luminance"></span>

#### LUMINANCE l

`LUMINANCE l` - Brightness for colors that glow. l is a byte value. Luminance is not generally used by LDraw renderers, but may be used for translation to other rendering systems. LUMINANCE is optional.

<span id="finish"></span>

#### Finishes

Only one of CHROME, PEARLESCENT, RUBBER, MATTE_METALLIC, METAL and MATERIAL may be specified for a single color. They all specify the finish/texture to be applied to an object being rendered. Other finish-tags may be defined over time.

<span id="chrome"></span>

##### CHROME

`CHROME` - A flag indicating that surfaces should have a mirror-like finish. Not currently used by LDraw-compatible programs, but may be implemented in the future. CHROME is optional, and may not appear with other finish tags.

<span id="pearl"></span>

##### PEARLESCENT

`PEARLESCENT` - A flag indicating that surfaces should have a finish like Lego's 'metallic' colors. These colors are commonly called 'pearlescent' by fans. Not currently implemented in LDraw-compatible programs. PEARLESCENT is optional, and and may not appear with other finish tags.

<span id="rubber"></span>

##### RUBBER

`RUBBER` - A flag indicating that surfaces should have a finish like rubber (typically rubber tubing or rubber tyres). RUBBER is optional, and may not appear with other finish tags.

<span id="matte"></span>

##### MATTE_METALLIC

`MATTE_METALLIC` - A flag indicating that surfaces should have a finish that simulates brushed metal finishes. MATTE_METALLIC is optional, and may not appear with other finish tags.

<span id="metal"></span>

##### METAL

`METAL` - A flag indicating that surfaces should have a finish like actual metal (not a simulation of a plastic simulation of metal). METAL is optional, and may not appear with other finish tags.

<span id="material"></span>

##### MATERIAL

`MATERIAL [name ...]`- Some other surface finish requiring customized parameter(s). Name is an identifier. MATERIAL is optional, and may not appear with other finish tags. Since it may have complex parameters that don't follow the standard syntax of the !COLOUR statement, MATERIAL should be the last tag in the !COLOUR statement.

The following MATERIAL definitions are official:

` GLITTER VALUE v [ALPHA a] [LUMINANCE l] FRACTION f VFRACTION vf SIZE s | MINSIZE min MAXSIZE max`\
`SPECKLE VALUE v [ALPHA a] [LUMINANCE l] FRACTION f SIZE s | MINSIZE min MAXSIZE max`\
`FABRIC [VELVET | CANVAS | STRING | FUR] `

GLITTER is used to specify a color that includes glitter mixed into the transparent plastic. Individual glitter grains are assumed to be flat squares, with arbitrary orientation.\
SPECKLE is used to specify a color that has a speckled pattern of an alternate color on its surface. Individual speckle grains are assumed to be roughly round.\
FABRIC is used to specify a surface finish for fabric. Omitting the second qualifier assumes a finish similar to the fabric used in Minifig capes.

FRACTION f is the portion of the surface that uses the alternate color, expressed as a decimal number greater than 0.0 and less than 1.0.\
VFRACTION vf is the portion of the volume that uses the alternate color, expressed as a decimal number greater than 0.0 and less than 1.0. Renderers that support volume rendering will use this value instead of the FRACTION value.\
SIZE is the size of each speckle/glitter grain, in LDraw units. It must be greater than 0. This is mutually exclusive with MINSIZE and MAXSIZE.\
MINSIZE and MAXSIZE provide a range of sizes for grains, in LDraw units. If either of these is specified, both must be specified, and they are mutually exclusive with SIZE.

Here is an example usage of SPECKLE:

`0 !COLOUR Speckle_Black_Silver CODE 132 VALUE #000000 EDGE #595959 MATERIAL SPECKLE VALUE #595959 FRACTION 0.4 MINSIZE 1 MAXSIZE 3`

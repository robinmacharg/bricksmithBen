<!-- Source: https://www.ldraw.org/texmap-spec.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Texture Mapping (!TEXMAP) Language Extension

**Maintained by:** LDraw.org Standards Board\
**Revision:** 01-Aug-2020

**Revision History:**\
30-Oct-2012 - Original\
01-Aug-2020 - Clarified fallback section and added search path examples

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="purpose"></span>

### Purpose

This document describes the !TEXMAP meta-statement, which contains a set of commands for including texture maps in LDraw files.

<span id="syntax"></span>

### Syntax

`0 !TEXMAP (START | NEXT) <method> <parameters> <pngfile> [GLOSSMAP pngfile] `

` 0 !: <geometry1>`\
`...`\
`<geometry2>`\
`... `

`0 !TEXMAP FALLBACK `

` <geometry3>`\
`... `

`0 !TEXMAP END `

<span id="excla"></span>

#### !:

`!:`\
This is used to specify texture mapped geometry that will be ignored by renderers that do not support the !TEXMAP meta-statement. This command must not be nested inside itself. Note: the actual meta-command here is the colon. This was carefully chosen to be brief, while not conflicting with existing software (since : isn't an existing meta-command). It also makes reading the files easier.

<span id="texmap"></span>

#### !TEXMAP

This is the main texture mapping meta-command.

The START command indicates that the given texture should be used. (If another texture is currently in use, it is pushed onto a stack for retrieval when an END command is given.) This texture will remain in effect until:

- An END is given within the current file
- The file in which the START is located ends
- A STEP command is reached


The texture will remain active when processing an included file unless overridden within that file.

The FALLBACK command is a section marker. In a TEXMAP supporting application, all geometry lines (whether following the 0 !: comment marker, or presented as standard LDRAW geometry: geometry1 or geometry2 lines) between START and FALLBACK are to be used as geometry and have the texture applied. All geometry between FALLBACK and END are ignored. In applications that don't support TEXMAP, nothing needs to be done, and all non-commented geometry is generated as normal (though the LDRAW parts author should be very cautious not to introduce unintended non-commented geometry lines into the START to FALLBACK section).

Note: the FALLBACK section is always optional, although it is highly recommended any time there is no geometry2 section.

In general, the START to FALLBACK section will contain only geometry following the special comment marker 0 !:, and geometry between FALLBACK and END will not.

NOTE: be cautious (and think through your approach) when including geometry2 lines. This feature is present for use generally in the case where the textured and non-textured FALLBACK geometry are the same. This is a rare occurrence, and normally would not be used.

The END command stops using the current texture and restores the previous texture to current status. This means that nested commands with START will form a stack of textures and the END command will pop those textures. However, END cannot appear in a different file from START. If an END command is given in a sub file without a START having been given in that same file, the END has no effect.

The NEXT command is a shortcut to make a texture work only for the next 1, 2, 3, 4, or 5 line. It would be equivalent to use the START command and then to place an END command immediately after the next 1, 2, 3, 4, or 5 line (with no FALLBACK possible). The first non-blank line following this command **must not** be line type 0. If it is, the NEXT command itself should be ignored (and an error should be generated, if in an environment that reports errors to the user).

The method token specifies the projection method to use for the texture map. Each projection method has its own unique set of parameters, and parameter parsing must be based on the method. Projection methods (and their parameters) are described below.

The first PNG file represents the texture bitmap to apply. The PNG can be B&W or color and if an alpha channel exists, it should be applied appropriately (allowing the part color to show through). The second optional PNG is used as a glossmap. It should be a single channel image where the value indicates the amount of specularity to add at the part of the texture map (RG and B are currently ignored – but reserved – in gloss maps, and the A (alpha) channel determines the amount of gloss at a given texel).

File names that contain spaces must be enclosed in double quotes ("). Additionally, a search for the specified texture file will first be attempted after adding a "textures/" prefix to the filename and following the standard LDraw search path. If no file is found, the search will be repeated without the "textures/" prefix. Filenames that themselves contain double quotes must use \\ as an escape character immediately prior to the double quote. The \\ character itself must be doubled up (\\\\) in order to be used to specify a sub-directory, but it is recommended that / be used instead in this case. (In LDraw files, \\ and / are interchangeable as path separators.)

Search path examples:\
`0 !TEXMAP ... 123.png` will look for `textures/123.png` then `123.png`\
`0 !TEXMAP ... s/123.png` will look for `textures/s/123.png` then `s/123.png`

<span id="projection_methods"></span>

#### Projection Methods

There are three possible methods that can be used to apply textures: PLANAR, CYLINDRICAL, and SPHERICAL.

<span id="planar"></span>

##### PLANAR

<img src="https://www.ldraw.org/uploads/images/Articles/LSC_Textur_Planar.png" class="ui right floated image" alt="PLANAR diagram" />

The parameters for PLANAR are:

`x1 y1 z1 x2 y2 z2 x3 y3 z3`

These three points represent 3 corners of the texture map in world coordinates. They form a plane onto which objects can be projected and they also represent the extents of the texture.

In addition, points 1 and 2 represent a plane (P1) perpendicular to the texture where point 1 lies on the plane and the normal to the plane follows the line from point 1 to 2. Similarly points 1 and 3 represent a plane (P2) which is perpendicular to both planes. This plane also contains point 1 but its normal follows the line from point 1 to 3.

Now to map from world coordinates to texture coordinates, U is given by the distance between a point and plane P1 divided by the length of the vector from point 1 to point 2. V is given by the distance between a point and plane P2 divided by the length of the vector from point 1 to point 3. Now U and V are values normalized to between 0 and 1. These can now be mapped to the pixels of the texture map.

<span id="cylindrical"></span>

##### CYLINDRICAL

<img src="https://www.ldraw.org/uploads/images/Articles/tex_cyl.png" class="ui right floated image" alt="CYLINDRICAL diagram" />

The parameters for CYLINDRICAL are:

`x1 y1 z1 x2 y2 z2 x3 y3 z3 a`

The first point represents the bottom center of the cylinder. The second point represents the top center of the cylinder. The third point represents a location on the outer edge of the cylinder bottom where the center-bottom of the texture would touch. The angle indicates the how much of the cylinder is mapped by the texture and so the extents would be –a/2 to a/2 as measured relative to the radial line from point 1 to point 3.

Now to map from world coordinates to texture coordinates, U is given by the angle between the vector formed by points 1 and 3 and the vector formed by point 1 and a world point that has been projected to the plane in which the base of the cylinder occupies. This angle is then divided by the "a" parameter to normalize it to the 0 to 1 range. V is given as the distance of a point from the plane occupied by the base of the cylinder and divided by the length of the vector from point 1 to point 2.

<span id="spherical"></span>

##### SPHERICAL

<img src="https://www.ldraw.org/uploads/images/Articles/tex_sphere.png" class="ui right floated image" alt="SPHERICAL" />

The parameters for SPHERICAL are:

`x1 y1 z1 x2 y2 z2 x3 y3 z3 a b`

The first point represents the center of the sphere. The second point represents a point on the sphere where the center of the texture map will touch. The third point is used to form a plane (P1) that is perpendicular to the texture and bisects it horizontally. An additional plane (P2) can be computed by using points 1 and 2 and generating a 3rd point along the normal of P1. P2 will be perpendicular to both P1 and the texture and will bisect the texture vertically. The two angles indicate the extents of the sphere that get mapped to. These are –a/2 to a/2 and –b/2 to b/2 as measured relative to the vector from point 1 to point 2 and within the planes P1 and P2 respectively.

Now to map world coordinates to texture coordinates, U is given by the angle between the vector formed by points 1 and 2 and the vector formed by point 1 and a world point that has been projected to the plane P1. The angle is divided by "a" to normalize it to between 0 and 1. V is given by the angle between the vector formed by points 1 and 2 and the vector formed by point 1 and a world point that has been projected to the plane P2. The angle is divided by "b" to normalize it.

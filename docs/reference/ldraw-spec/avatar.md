<!-- Source: https://www.ldraw.org/avatar-spec.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# !AVATAR Language Extension

**Maintained by:** LDraw.org Standards Board\
**Revision:** 1, 2024-06-19

**Revision History:**

1: Initial

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="spec"></span>

### Purpose

Outlines the !AVATAR Meta statement that provides information to display a typical example of a part in a given category.

<span id="scope"></span>

### Scope

The !AVATAR meta command is an optional command intended to allow an editor to display a typical example of a part in a given category (as defined by the !CATEGORY meta). Defined !AVATAR statements will be located within the LDConfig.ldr file. For an editor that chooses to implement this specification, if an !AVATAR statement for a given !CATEGORY is not defined, the choice of avatar is at the option of the editor developer.

<span id="avatar"></span>

### !AVATAR Syntax

`0 !AVATAR CATEGORY "<category>" DESCRIPTION "<description>" PART <rotation maxtrix> "<part file>"`

\<category\> is the category name from the list of approved !CATEGORY categories\
\<description\> is a short (approximately 4 words or less) description of the category. This will typically be the pluralized form of the category\
\<rotation matrix\> is the 9 element rotation matrix as defined by the LDraw File Format Type 1 line definition. Only rotations are allowed in this matrix, not scale factors or skews.\
\<part file\> is the part file reference as defined by the LDraw File Format Type 1 line definition

<!-- Source: https://www.ldraw.org/article/340.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# !CATEGORY and !KEYWORDS Language Extension

**Maintained by:** LDraw.org Standards Committee\
**Revision:** 1.7, 18-Nov-2022

**Revision History:**\
1.5 Changed Propellor to Propeller 1.6 Added Duplo 1.7 Added Moved, Helper, and String. Clarified use for Helper, Moved, and Obsolete.

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="spec"></span>

### Purpose

Outlines the !CATEGORY and !KEYWORDS Meta statements that provide information for organizing and searching the part library.

<span id="scope"></span>

### Scope

The !CATEGORY and !KEYWORDS meta-statements provide information for organizing and searching the LDraw parts library. Before these meta-statements were defined, the only way to organize the library was by the descriptive name and part number. While useful, the name and number do not provide enough information to thoroughly catalog a large library of parts.

The !CATEGORY meta-statement provides a means to place the part in a comprehensive classification system and is used for locating a part within a list of categories, while the !KEYWORDS meta-statement provides a means for associating free-form search terms with the part.

The !CATEGORY meta-statement is used exclusively in part files and subparts; it does not appear in models or primitives.\
The !KEYWORDS meta-statement is used exclusively in part files and models; it does not appear in subparts or primitives.

<span id="category"></span>

### !CATEGORY Syntax

`0 !CATEGORY <categoryname>`

The !CATEGORY meta-statement, if present, must appear in the part header, as defined by the [LDraw.org Official Library Header Specification](https://www.ldraw.org/article/398). A part can have only one !CATEGORY meta-statement. If a part has no !CATEGORY meta-statement, the category is assumed to be the first word in the part name (ie. the first word of the first line of the part file).

The text after !CATEGORY is treated as a single category name. So, if a part contained the meta-statement `"0 !CATEGORY Minifig Accessory"` it would specify that the part belongs in the category "Minifig Accessory" (as opposed to belonging to the "Accessory" subcategory of the "Minifig" category or both the "Minifig" and "Accessory" categories).

<span id="categorylist"></span>

#### Approved !CATEGORY list

New categories are added by the Parts Library administrators. The current list of approved categories is:

- Animal
- Antenna
- Arch
- Arm
- Bar
- Baseplate
- Belville
- Boat
- Bracket
- Brick
- Car
- Clikits
- Cockpit
- Cone
- Constraction
- Constraction Accessory
- Container
- Conveyor
- Crane
- Cylinder
- Dish
- Door
- Duplo
- Electric
- Exhaust
- Fence
- Figure
- Figure Accessory
- Flag
- Flexible
- Freestyle
- Garage
- Glass
- Helper
- Hinge
- Homemaker
- Hose
- Ladder
- Magnet
- Minifig Head
- Minifig Upper
- Minifig Lower
- Minifig Leg
- Minifig Hips
- Minifig Arm
- Minifig Hand
- Minifig Torso
- Minifig Body
- Minifig Assembly
- Minifig Accessory
- Minifig Footwear
- Minifig Headwear
- Minifig Hipwear
- Minifig Neckwear
- Monorail
- Modulex
- Moved
- Mursten
- Obsolete
- Panel
- Plane
- Plant
- Plate
- Platform
- Propeller
- Quatro
- Rack
- Roadsign
- Rock
- Scala
- Screw
- Sheet Cardboard
- Sheet Fabric
- Sheet Plastic
- Slope
- Sphere
- Staircase
- Sticker
- Sticker Shortcut
- String
- Support
- Tail
- Tap
- Technic
- Tile
- Tipper
- Tractor
- Trailer
- Train
- Turntable
- Tyre
- Vehicle
- Wedge
- Wheel
- Winch
- Window
- Windscreen
- Wing
- Znap
- Minifig
- Pov-RAY
- Lever
- Grab
- Forklift

<span id="keywords"></span>

### !KEYWORDS Syntax

`0 !KEYWORDS <first keyword>, <second keyword>, ..., <last keyword>`

The !KEYWORDS meta-statement(s), if present, must appear in the part header, as defined by the [LDraw.org Official Library Header Specification](https://www.ldraw.org/article/398). A part may have many !KEYWORDS meta-statements.

The list of words and phrases following the !KEYWORDS meta-statement is delimited by commas. Any white-space should be reduced to a single space, and leading and trailing spaces on the keyword ignored. Multiple lines can be used to structure or group keywords into themes. The lines should be limited to 80 characters. Words and terms from the part name are not allowed; neither is the part number.

The keywords are a list of words and phrases that further describe the part and specify any terms the author feels would aid in identifying the part. Keywords typically include: terms not included in the part's descriptive name; geometric terms; synonyms (for example, if the part name includes the term "rounded", a keyword might be "curved"); the unique set the part appeared in; LEGO official playthemes; other category names that the part is similar to (for example, wheels without separate tyres could also have the keyword "Tyre"); alternate spellings.

<span id="examples"></span>

### Examples

    0 Landing Skids
    0 Name: 30248.dat
    ...
    0 !CATEGORY Plane
    0 !KEYWORDS helicopter, skid, rail, Arctic, sled, ski, sleigh
    0 !KEYWORDS Belville, Town

    0 Tile 1 x 2 with Playing Cards Pattern
    0 Name: 3069bpw1.dat
    ...
    0 !KEYWORDS western, wild west, spaghetti western, horse opera, cowboy
    0 !KEYWORDS bandit, desperado, cardsharper, swindler
    0 !KEYWORDS casino, bridge, blackjack, twenty-one, baccarat, chemin de fer
    0 !KEYWORDS poker, stud, stud poker, strip poker, straight poker, penny ante
    0 !KEYWORDS penny ante poker, high-low, draw, draw poker, pair, straight
    0 !KEYWORDS flush, full house, straight flush, royal flush, eight-card stud

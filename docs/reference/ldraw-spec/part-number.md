<!-- Source: https://www.ldraw.org/part-number-spec.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Official Library Part Number Specification

**Maintained by:** LDraw.org Library Administrator\
**Revision:** 2 (8-May-2024)

**Revision History:**\
Revision 1: Original Revision 2: Clarified p/c/d suffix codes.

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="intro"></span>

### Introduction

This document outlines the LDraw part numbering schema for the Offficial Library. While the goal is to be comprehensive, it may not outline all situations involving the numbering of parts for the Official Library. As these rules have evolved over time, there may be part in the Official Library that do not conform. This legacy numbering remains in place for backwards compatibility reasons. Do not submit parts to the Parts Tracker if you are unsure. When in doubt, please ask! You can post to everyone on the [LDraw Forums](https://forums.ldraw.org/forum-18.html), or email the [parts library administrator](https://www.ldraw.org/cdn-cgi/l/email-protection#b9c9d8cbcdcaf9d5ddcbd8ce97d6cbde).

<span id="general"></span>

### General Part Numbering

<span id="known_num"></span>

#### Known Part Numbers

If the part number (Design ID) used by LEGO is known, then that number should be used.

<span id="known_num_where"></span>

##### Where to Find Part Numbers

For modern parts, these numbers are often moulded in a discreet place on the part. These are typically four digit numbers in the range 2001-9999, or five-digit numbers. Don't be confused by a number of the form *n-nn* (eg. 4-01), or even single numbers or letters on older parts - these are probably something to do with identifying individual moulds, they are not the part number.

<span id="known_num_eleid"></span>

##### Part Numbers vs. Element IDs

The numbers listed next to parts at the back of instruction manuals are not the part numbers (also called Design IDs) LDraw.org uses as its nomenclature, but the Element IDs or Item IDs, a number that signifies both the part shape and color. Since LDraw parts can be any color, LDraw does not use Element IDs but solely Design IDs. For example, a Brick 1x2's Design ID is "3004" while a Tan Brick 1x2's Element ID is "4109995". Hence you will not find 4109995 in the LDraw parts library.

<span id="unknown_num"></span>

#### Unknown Part Numbers

If LEGO part number is not known, "u" prefix is used (e.g. u1234.dat). The part in question gets a file name with uNNNN.dat format, these filenames thus ranging from u1.dat to u9999.dat. This number will be requested from the Parts Library Admin prior to submitting the part to the Parts Tracker. The part will retain the u-prefixed number as long as the part's true number is unknown. If the LEGO part number is identified during the review process, then the part will renumbered and the u-prefixed number will become available for re-use.

Prior to 2010, a three-digit part number was used. That range of numbers, however, was exhausted. During development, and for posting to the Parts Tracker, the three-digit number was preceded with an "x" (e.g. x123.dat), and upon inclusion in an official release, the "x" was removed. Parts that were on the Parts Tracker in February 2010 and not listed by Peeron, do not need be renamed to u9NNN numbers. They will continue to be renamed xNNN.dat -\> NNN.dat upon release.

For backwards compatability reasons, nonconforming parts already in the Official Library will not be renumbered solely for the purpose of conforming to this rule.

<span id="multi_num"></span>

#### Mould Variants/Different Versions or Parts with the Same Number

If the parts have different numbers, the different LEGO (design ID) numbers will be used. More commonly, the different variations will have the same number. This is managed by adding a single alpha character to the end of the base part number (e.g. 3626a.DAT and 3626a.DAT, the solid stud and hollow stud versions of the minifig head). If, prior to the second version being authored, one version of the part was released using just the official part number (no alpha-character suffix), it will be renumbered/moved to use an alpha-suffix. If the official part number is unknown, then separate uNNNN numbers will be used for each version.

Occaisonally a part is included with geometry that is not quite correct or the part number itself is incorrect. In this instance, in order to preserve backward compatability, when a corrected part is made, it's part number will follow these rules and the non-alpha suffix part will be made obsolete.

<span id="sprue_num"></span>

#### Parts on Sprues or Runners

Some small parts are delivered from LEGO still connected to a sprue (or runner) containing several different parts (e.g. the castle feathers or the coins). These are numbered in the same way as multi-version parts - by adding a single character suffix to the end of the part number.

<span id="subparts"></span>

#### Subparts

Subparts, which are stored in the parts\\s subdirectory, should bear some relationship to their "parent" main part. Where there is extensive shared geometry, subparts may be used by parent parts with a different main number. They are numbered by appending a `sNN` suffix to the part number of the main part.\
Examples:\
s\\1234s01.dat for 1234.dat\
s\\1234p56s01.dat for 1234p56.dat\>

<span id="primitives"></span>

#### Primitives

Primitives are essentially highly reusable components, and for ease of use have highly coded names. Existing primitives are described in the [Primitives Reference](https://www.ldraw.org/primitive-reference). If there is a need for a new class of primitives, the [Parts Library Admins](https://www.ldraw.org/parts@ldraw.org) should contacted prior to submission.

<span id="studgroups"></span>

#### Stud groups

Stud groups are provided to reduce the size of part files with many regularly spaced studs. The naming convention is as following:

`stug`**`N`**`-`**`X`**`x`**`Z`**`.dat`

Where:

- **N** = type of stud (regular stud, hollow stud, underside stud, …)
- **X** = number of studs on the x axis
- **Z** = number of studs on the z axis

To prevent an overload of the library with all sort of combinations, the numbers on the x and z axis are limited to:

- 1xZ stugs
- Xx1 stugs (Due to stud orientation you cannot rotate a 1xZ stud group by 90 degrees to get a Xx1 stud group)
- XxZ stugs where X==Z

<span id="textures"></span>

#### Texture Image Files

Texture image files will have the same number as it's parent file. If more than one texture image is used for a part, a suffix of the part author's choice is added to the files. Examples:\
4141698a.png for 4141698a.dat\
6092p01wall1.png and 6092p01wall2.png for 6092p01.dat

<span id="third"></span>

#### Third Party Parts

Third party parts will have a tNNNN.dat format where NNNN is a number assigned by the Library Adminstrator

<span id="shortcut"></span>

### Shortcut (Assembly) Part Numbering

<span id="shortcut_gen"></span>

#### General Shortcut Part Numbering

Shortcut files used when several separate parts are typically delivered from LEGO pre-assembled or are frequently used in combination. These are numbered using the official LEGO number for the composite part, if known, or by appending `cNN` to the part number of one of the individual parts.

<span id="shortcut_mov"></span>

#### Shortcuts with More Than One Physical Configuration

Flexible parts such as springs, hoses, ropes, chains, or cloth can exist in more than one configuration.

If the flexible part is of a nature that smaller component parts are used to mimic the curving of the part (e.g. ribbed hoses, flexible axles), these parts with have a suffix of `kNN`

In all cases, the final assembly will have a suffix of `-fN`. The default or "at-rest" position will always be `-f1`

<span id="pattern"></span>

### Patterned Part Numbering

<span id="pattern_gen"></span>

#### General Patterned Part Numbering

In LDraw, a part with printing is called patterned. The decorative printing is the pattern. LDraw has it's own pattern numbering scheme, do not use the pattern code listed on other inventory websites.

The number for a patterned part is the same as the number for plain, or base, part, plus a 'p' and a 2 (or 3) digit code:\
`BBBBBpCC(C).dat`\
Where:\
`BBBBB` is the 3-5 digit base number\
`CC(C) or XXXX` is the code for the pattern. The CC(C) code can have a mix of letters and numbers. The XXXX code is only numbers.

<span id="pattern_codes"></span>

#### Patterned Part Code

Typically, the first digit of the code helps to identify which theme or product line the pattern appears in (themes listed below). This is not a requirement, both because many patterned parts appear in multiple themes, and because this approach to pattern-numbering has evolved over time. If a theme is full (i.e. 0-z are in use), then any available code can be used. If all codes are in use (i.e. 00-zz) for a given part number then the first available XXXX number should be assigned (e.g. 0001)

<table class="ui collapsing striped celled table">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<thead>
<tr>
<th>Range</th>
<th>Assignment</th>
</tr>
</thead>
<tbody>
<tr>
<td>0X</td>
<td>General/Miscellaneous and Town</td>
</tr>
<tr>
<td>1X,2X</td>
<td>Town, including Paradisa</td>
</tr>
<tr>
<td>3X</td>
<td>Pirates, Soldiers, Islanders</td>
</tr>
<tr>
<td>4X</td>
<td>Castle</td>
</tr>
<tr>
<td>5X,6X</td>
<td>Space</td>
</tr>
<tr>
<td>7X,8X,9X</td>
<td>Modern Town</td>
</tr>
<tr>
<td>aX</td>
<td>Action (Adventurers, Aquazone, Alpha Team, Rock Raiders)</td>
</tr>
<tr>
<td>bX</td>
<td>Superheroes</td>
</tr>
<tr>
<td>cX</td>
<td>Control Panels, dials, gauges, keyboards, readouts, etc. / Superheroes (minifig parts)</td>
</tr>
<tr>
<td>cXY</td>
<td>Patterned parts for Collectable Minifigures (heads, torsos, arms, hips, legs) from numbered series:
<ul>
<li>Note: X cannot be 0</li>
<li>X=series number : 1,2,3,...a,b,c,..., Y=sequence : 1-9,a-h (a=10...h=17)</li>
<li>X=z for Collectable Minifigures from accessory packs (where these differ from series versions)</li>
</ul></td>
</tr>
<tr>
<td>dX</td>
<td>Studios</td>
</tr>
<tr>
<td>dXY</td>
<td>Patterned parts for Collectable Minifigures (heads, torsos, arms, hips, legs) from unnumbered series:
<ul>
<li>Note: X cannot be 0</li>
<li>X=1 for Simpsons series 1; Y=1-9,a-g</li>
<li>X=2 for The LEGO Movie; Y=1-9,a-g</li>
<li>X=3 for Simpsons series 2; Y=1-9,a-g</li>
<li>X=4 for Disney; Y=1-9,a-i</li>
<li>X=5 for 2016 German Football Team; Y=1-9,a-g</li>
<li>X=6 for The LEGO Batman Movie; Y=1-9,a-k</li>
<li>X=7 for The LEGO Ninjago Movie; Y=1-9,a-k</li>
<li>X=8 for The LEGO Batman Movie series 2; Y=1-9,a-k</li>
<li>X=9 for Wizarding World; Y=1-9, a-m</li>
<li>X=a for The LEGO Movie 2; Y=1-9, a-k</li>
<li>X=b for Disney series 2; Y=1-9, a-i</li>
<li>X=c for DC Super Heroes; Y=1-9,a-g</li>
<li>X=d for Harry Potter series 2; Y=1-9,a-g</li>
<li>X=e for Looney Tunes; Y=1-9,a-c</li>
<li>X=f for Marvel Studios; Y=1-9,a-c</li>
<li>X=g for The Muppets; Y=1-9,a-c</li>
<li>X=h for Disney 100 Years; Y=1-9,a-i</li>
<li>X=i for Marvel Studios series 2; Y=1-9,a-c</li>
<li>X=j for 2012 Team GB; Y=1-9</li>
</ul></td>
</tr>
<tr>
<td>eX</td>
<td>Nexo Knights</td>
</tr>
<tr>
<td>fX</td>
<td>Fabuland and Scala or Castle (minifig parts)</td>
</tr>
<tr>
<td>gX</td>
<td>Soccer, Basketball</td>
</tr>
<tr>
<td>hX</td>
<td>Harry Potter</td>
</tr>
<tr>
<td>jX</td>
<td>Indiana Jones</td>
</tr>
<tr>
<td>kX</td>
<td>Cars (Disney Pixar)</td>
</tr>
<tr>
<td>mX</td>
<td>Middle Earth (Lord of the Rings), Elves</td>
</tr>
<tr>
<td>nX</td>
<td>Ninja</td>
</tr>
<tr>
<td>qX</td>
<td>Pharaoh's Quest</td>
</tr>
<tr>
<td>rX,sX</td>
<td>Star Wars</td>
</tr>
<tr>
<td>tX</td>
<td>General Textual Patterns (lettering and numbers) and Trademark items (Corporate Logos, etc)</td>
</tr>
<tr>
<td>uX</td>
<td>Extended textual patterns or Modern Town/City (minifig parts)</td>
</tr>
<tr>
<td>vX</td>
<td>Extended textual patterns</td>
</tr>
<tr>
<td>wX</td>
<td>Extended textual patterns or Western (minifig parts)</td>
</tr>
<tr>
<td>xX</td>
<td>Miscellaneous Licenses (SpongeBob SquarePants, Ideas)</td>
</tr>
<tr>
<td>yX</td>
<td>Racing (Racers, Tiny Turbos, Speed Champions)</td>
</tr>
<tr>
<td>zX</td>
<td>Brickheadz</td>
</tr>
</tbody>
</table>

<span id="sticker"></span>

### Sticker Part Numbering

<span id="sticker_gen"></span>

#### General Sticker Part Numbering

Official LEGO numbering for sticker sheets has changed over time

1.  no copyright date sheets - 4-digit numbers: 3xxx, 4xxx or 6-digit numbers: 004xxx
2.  no copyright date sheets - 6-digit numbers: 168xxx, 169xxx, 197xxx, 820xxx, 821xxx
3.  ©1993 / 1994 - 6-digit numbers: 168xxx, 169xxx, 822xxx; a few 7-digit numbers: 4100xxx
4.  ©1995 - 2000 - combo 5-digit/7-digit numbers: 71xxx/41xxxxx, 72xxx/41xxxxx
5.  ©2000 - 2003 - combo 5-digit/7-digit numbers: 2xxxx/41xxxxx, 4xxxx/41xxxxx, 4xxxx/42xxxxx; a few 7-digit numbers: 42xxxxx
6.  ©2004 onwards - combo 5-digit/7-digit numbers: 5xxxx/4xxxxxx, 6xxxx/4xxxxxx, 7xxxx/4xxxxxx, 8xxxx/4xxxxxx
7.  ©2012 onwards - combo 5-digit/7-digit numbers: 1xxxx/60xxxxx

Sticker parts should be based on the sticker sheet number, if known, with a character suffix (a, b, c, etc.) for each sticker. If the sticker sheet contains only a single sticker or multiple copies of the same sticker, a suffix (a) should still be used. If the stickers are numbered on the sticker sheet, the printed sticker number and the character suffix should correspond to the sequence where a=1, b=2, ... , z=26, aa=27, ab=28, etc. Four digit numbers should be prefixed with two zeros to avoid clashes with LEGO parts (e.g. 004845a.dat, not 4845a.dat). Stickers from sheets with combo 5-digit/7-digit numbers should use the 7-digit number.

<span id="sticker_unk"></span>

#### Sticker Sheets with No Number

Stickers from sheets with no printed number or of unknown number should use the next available `sN`, `sNN` or `sNNN` number.

<span id="sticker_gen"></span>

#### Formed Stickers Parts

Formed versions of stickers to match the surface of a part should use the flat sticker part number with a `cNN` or `cXXXX` suffix. The NN suffix can have a mix of letters and numbers. The XXXX suffix is only numbers. If all NN suffixes are in use (i.e. 00-zz) for a given part number then the first available XXXX number should be assigned (e.g. 0001)

<span id="sticker_shortcut"></span>

#### Sticker Shortcuts

Sticker shortcuts should use the number of the part that the sticker is applied to with a `dNN` or `dXXXX` suffix. The NN suffix can have a mix of letters and numbers. The XXXX suffix is only numbers. If all NN suffixes are in use (i.e. 00-zz) for a given part number then the first available XXXX number should be assigned (e.g. 0001)

<span id="quick_ref"></span>

### Part Numbering Quick Reference Table

<table class="ui collapsing striped celled table">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<thead>
<tr>
<th class="five wide">Part number pattern<br />
(<em>a</em> = alpha, <em>N</em>= numeric, <em>x</em> = alphanumeric)</th>
<th>Usage</th>
</tr>
</thead>
<tbody>
<tr>
<td><em>NNN</em></td>
<td>Regular part of unknown LEGO number (see also uNNNN, below).</td>
</tr>
<tr>
<td><em>NNNN</em> or <em>NNNNN</em></td>
<td>Regular part of known LEGO number.</td>
</tr>
<tr>
<td><em>NNN</em>c<em>NN/XXXX</em>, <em>NNNN</em>c<em>NN/XXXX</em>, <em>NNNNN</em>c<em>NN/XXXX</em></td>
<td>Shortcut assembly of part <em>NNN</em>, <em>NNNN</em> or <em>NNNNN</em> with other parts or formed version of flexible part <em>NNN</em>, <em>NNNN</em> or <em>NNNNN</em>.</td>
</tr>
<tr>
<td><em>NNN</em>c<em>NN</em>-f<em>n</em>, <em>NNNN</em>c<em>NN</em>-f<em>n</em>, <em>NNNNN</em>c<em>NN</em>-f<em>n</em></td>
<td>Positional variant of shortcut assembly of movable parts, comprising part <em>NNN</em>, <em>NNNN</em> or <em>NNNNN</em> with other parts.</td>
</tr>
<tr>
<td><em>NNN</em>d<em>NN/XXXX</em>, <em>NNNN</em>d<em>NN/XXXX</em>, <em>NNNNN</em>d<em>NN/XXXX</em></td>
<td>Shortcut assembly of part <em>NNN</em> , <em>NNNN</em> or <em>NNNNN</em> with a sticker as used in an official set.</td>
</tr>
<tr>
<td><em>NNN</em>p<em>CC(C)/XXXX</em>, <em>NNNN</em>p<em>CC(C)/XXXX</em>, <em>NNNNN</em>p<em>CC(C)/XXXX</em></td>
<td>Patterned version of regular part.</td>
</tr>
<tr>
<td><em>NNN[a-z]</em>p<em>CC(C)/XXXX</em>, <em>NNNN[a-z]</em>p<em>CC(C)/XXXX</em>, <em>NNNNN[a-z]</em>p<em>CC(C)/XXXX</em></td>
<td>Patterned version of regular part variant.</td>
</tr>
<tr>
<td>s/<em>NNN</em>s<em>NN</em>, s/<em>NNNN</em>s<em>NN</em>, s/<em>NNNNN</em>s<em>NN</em></td>
<td>Subfiles - stored in the parts/s directory.</td>
</tr>
<tr>
<td><em>NNNa, NNNNa, NNNNNa</em></td>
<td>Regular part variant (<em>a</em> = a, b, c for successive versions of part, sequenced chronologically), or mini-part (<em>a</em> = a, b, c for each mini-part on the same runner or included in a small bag), or to maintain backward compatibility if an incorrect number is released into the official library.</td>
</tr>
<tr>
<td>s<em>NNNN</em></td>
<td>Sticker of unknown LEGO number.</td>
</tr>
<tr>
<td>t<em>NNNN</em></td>
<td>LEGO-compatible third-party part.</td>
</tr>
<tr>
<td>u<em>NNNN</em></td>
<td>Part of unknown LEGO number</td>
</tr>
</tbody>
</table>

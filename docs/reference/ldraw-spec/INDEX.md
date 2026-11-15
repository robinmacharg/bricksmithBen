<!-- Fetched: 2026-11-15 -->

# LDraw specifications: local reference copies

These files are local copies of the official LDraw documents listed on the LDraw.org Documentation page
(https://www.ldraw.org/docs-main.html), fetched 2026-11-15. Each file starts with a comment block that gives
the exact source URL. The text is a mechanical HTML-to-Markdown conversion (pandoc). It was not edited for
meaning, and typos in the source were left as they are (e.g. "an ratified", "adminstrative",
"31-Apr-2009", "01-Arr-2025", "Revision: Revision: 2").

## Saved specifications

The "Revision" column is copied exactly as the page prints it.

| Docs-page section | Title (page `<title>`) | Revision as stated on page | File | Source URL |
|---|---|---|---|---|
| LDraw File Format | LDraw File Format Specification | 1.0.2, 29-Apr-2012 | [file-format.md](file-format.md) | https://www.ldraw.org/article/218.html |
| LDraw File Format | Colour Definition (!COLOUR) Language Extension | 01-Apr-2025 (history: "31-Apr-2009 - Original Document", "01-Arr-2025 - Added FABRIC material") | [colour-definition.md](colour-definition.md) | https://www.ldraw.org/article/299.html |
| LDraw File Format | Back Face Culling (BFC) Language Extension | 09-Nov-2006 | [bfc.md](bfc.md) | https://www.ldraw.org/article/415.html |
| LDraw File Format | Texture Mapping (!TEXMAP) Language Extension | 01-Aug-2020 | [texmap.md](texmap.md) | https://www.ldraw.org/texmap-spec.html |
| LDraw File Format | !CATEGORY and !KEYWORDS Language Extension | 1.7, 18-Nov-2022 | [category-keywords.md](category-keywords.md) | https://www.ldraw.org/article/340.html |
| LDraw File Format | Multi-Part Document (MPD) and Image Embedding (!DATA) Language Extension | Revision: 2, 26-May-2020 | [mpd.md](mpd.md) | https://www.ldraw.org/article/47.html |
| LDraw File Format | Localisation Guideline | 06-Jan-2010 | [localisation.md](localisation.md) | https://www.ldraw.org/article/559.html |
| LDraw File Format | !AVATAR Language Extension | 1, 2024-06-19 | [avatar.md](avatar.md) | https://www.ldraw.org/avatar-spec.html |
| Official Parts Library Standards | LDraw.org Official Parts Library Specifications | 2.4 (03-Feb-2023) | [library-specifications.md](library-specifications.md) | https://www.ldraw.org/article/512.html |
| Official Parts Library Standards | Official Library Part Number Specification | 2 (8-May-2024) | [part-number.md](part-number.md) | https://www.ldraw.org/part-number-spec.html |
| Official Parts Library Standards | Official Library Header Specification | 21-Feb-2025 | [library-header.md](library-header.md) | https://www.ldraw.org/article/398.html |
| Official Parts Library Standards | LDraw.org Library Policies and FAQ | (none stated) | [library-policies-faq.md](library-policies-faq.md) | https://www.ldraw.org/pt-policies.html |
| Official Parts Library Standards | LDraw.org Library Sticker Box Standard | 22-Jul-2025 (history also lists 2-Aug-2025) | [sticker-box-standard.md](sticker-box-standard.md) | https://www.ldraw.org/docs-main/ldraw-org-official-library-standards/sticker-box-standard.html |
| OMR Standards | Official Model Repository (OMR) Specification | 17-Dec-2020 (history also lists 22-Nov-2023) | [omr-specification.md](omr-specification.md) | https://www.ldraw.org/article/593.html |
| OMR Standards | Rules and Procedures for the Official Model Repository | 22-Nov-2023 | [omr-rules.md](omr-rules.md) | https://www.ldraw.org/docs-main/official-model-repository-omr/rules-and-procedures-for-the-official-model-repository.html |
| Quick Reference Guides | Colour Definition Reference | (none stated) | [colour-definition-reference.md](colour-definition-reference.md) | https://www.ldraw.org/article/547.html |

## Linked but could not be fetched

None. Every URL above returned HTTP 200.

## Listed on the Documentation page but deliberately not saved

These are not file-format or library specifications, so they were not copied:

- Primitive Reference: https://wiki.ldraw.org/wiki/Primitives_Reference (LDraw.org wiki)
- Common Error Check Messages: https://www.ldraw.org/docs-main/ldraw-org-quick-reference-guides/common-error-check-messages.html
- LDraw.org Contributor Agreement: https://www.ldraw.org/article/349.html
- Legal Info: https://www.ldraw.org/docs-main/licenses/legal-info.html
- Governance articles (Bylaws https://www.ldraw.org/article/268.html, Policies And Procedures https://www.ldraw.org/article/281.html, Standards Board Charter https://www.ldraw.org/article/382.html)
- The data files linked from colour-definition-reference.md, https://library.ldraw.org/library/official/LDConfig.ldr and https://library.ldraw.org/library/official/LDCfgalt.ldr, were not downloaded.

## Items named in the task that are not separate documents on ldraw.org

None of these has its own entry on the Documentation page. This table shows where each one is covered in the saved files:

| Item | Where it is covered |
|---|---|
| Name / Author | library-header.md, sections `Name` and `Author` |
| !LDRAW_ORG | library-header.md, section `!LDRAW_ORG`; file-format.md, section "File Type" (which also lists older forms such as `0 LDRAW_ORG`, `0 Official LCAD`, `0 Unofficial`) |
| !LICENSE | library-header.md, section `!LICENSE` |
| !HELP, !CMDLINE, !HISTORY, !PREVIEW | library-header.md, sections "Syntax" and "Optional Meta Commands" |
| !CATEGORY, !KEYWORDS | category-keywords.md |
| !DATA | mpd.md |
| LDConfig.ldr / colour definitions | colour-definition.md (the !COLOUR syntax) and colour-definition-reference.md |
| STEP, WRITE/PRINT, CLEAR, PAUSE, SAVE (the original meta commands) | file-format.md, section "META Commands" |
| "LDraw Global Extensions" | No document by this name on the Documentation page, and the phrase does not appear in any saved file. |
| "Restrictions on the file format" | No document by this name on the Documentation page. localisation.md links "[LDraw.org File Format Restrictions for the Official Library](https://www.ldraw.org/article/512)", and that URL is the document saved as library-specifications.md (page title "LDraw.org Official Parts Library Specifications"). |

## Conversion notes

- Only the main article body was kept (`div#main_content`; for pt-policies.html and article/547.html, which have no such div, the first `div.ui.segment` after the "Documentation:" header). The site navigation, breadcrumbs, side table of contents and footer were removed.
- The `#` H1 in each file is the page `<title>` with the "LDraw.org - " prefix removed.
- Relative link and image URLs were made absolute (`https://www.ldraw.org/...`). Images were not downloaded.
- Info and note boxes (`<div class="ui info message">`) were flattened into plain paragraphs. Anchor `<span id=...>` elements and some complex tables were kept as raw HTML.
- In file-format.md, "Blended Colours" section, subscripts that the site draws as styled `<span>`s (n₁, n_b, n₂) come out as `n1`, `nb`, `n2`.
- `<pre>` blocks became indented code blocks. Backslashes in the source (e.g. `LDRAW\PARTS`) are Markdown-escaped as `\\` in prose, so they render as a single `\`. Inside code they appear literally.
- In file-format.md, "File Type", the source line "+ = obsolete/deprecated..." is written as `\+ = ...` so that Markdown does not turn it into a list item.
- Verification: for every file, the source HTML body and the rendered Markdown were each stripped to their text with all whitespace removed. The two strings compared identical, character for character.

## Non-official extensions: what ldraw.org says

- **The official specs do not define them.** None of the saved specification documents defines MLCad's `ROTSTEP`, `BUFEXCHG` or `GHOST`, or LSynth's `0 SYNTH` commands. Under "Unofficial META Commands", file-format.md links to "the list of known META commands and the programs that use them": http://wiki.ldraw.org/index.php?title=List_of_Known_Unofficial_META_Commands
- **The wiki page lists syntax only.** That wiki URL (the LDraw.org wiki) redirects to "Custom LDraw File Syntax Additions" (https://wiki.ldraw.org/index.php?title=Custom_LDraw_File_Syntax_Additions&oldid=6427, "This page was last edited on 22 February 2020, at 01:54."). The page was read but not saved here. It describes such additions as generally "a Bad Idea (TM)" and "tries to list all the existing custom syntax elements". It gives syntax lines only, with no semantics, including:
  - under **MLCad**: `ROTSTEP (<x-angle> <y-angle> <z-angle> [(REL| ADD | ABS)] | END)`, `BUFEXCHG (A-H) (STORE | RETRIEVE)`, `GHOST <LDRAW line>` (plus BACKGROUND, GROUP, MLCAD BGT/HIDE/SKIP_BEGIN/SKIP_END/SPRING/FLEXHOSE/RUBBER_BELT, ROTATION CENTER/CONFIG/AXLE);
  - under **LSynth**: `SYNTH BEGIN (RIBBED_TUBE | FLEXIBLE_TUBE | FLEX_CABLE | RIGID_TUBE | ELECTRIC_CABLE | PNEUMATIC_TUBE | FLEXIBLE_AXLE | FIBER_OPTIC_CABLE | RUBBER_BAND | CHAIN | PLASTIC_TREAD | RUBBER_TREAD)`, `SYNTH END`, `SYNTH (INSIDE | OUTSIDE | CROSS | SHOW | HIDE)`, `SYNTHESIZED BEGIN`, `SYNTHESIZED END`.
- **Further wiki pages were not fetched.** The wiki page links to `/wiki/MLCad` and `/wiki/LSynth`.
- **One official mention of LSynth.** The only official document that mentions LSynth is library-header.md, under "Optional Qualifiers" (`Flexible_Section`), where LSynth is given as an example application.
- **MLCad on the main site.** ldraw.org's site menu links an "MLCad.ini Download" page (https://www.ldraw.org/mlcad-ini-download.html). It was not fetched.

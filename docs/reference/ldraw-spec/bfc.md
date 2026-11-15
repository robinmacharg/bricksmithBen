<!-- Source: https://www.ldraw.org/article/415.html -->
<!-- Fetched: 2026-11-15 -->
<!-- Content: verbatim conversion of the published spec; not edited for meaning. -->

# Back Face Culling (BFC) Language Extension

**Maintained by:** LDraw.org Standards Board\
**Revision:** 09-Nov-2006

**Revision History:**\
09-Nov-2006: Original

This is an ratified, official LDraw.org document. Non-adminstrative changes can only be made with the approval of the maintainer.

<span id="purpose"></span>

### Purpose

To establish a standard for back face culling processing in LDraw-compatible rendering programs. This standard will include language extensions, definitions and expected processing effects.

In this document this standard will be called the BFC extension.

The standard must allow cross-compatible LDraw files. That is, LDraw-compatible rendering programs that don't support the BFC extension must render BFC-enabled LDraw files correctly, while renderers that support the BFC extensions must render non-BFC'ed LDraw files correctly.

To make this standard useful and effective, the LDraw parts library must be updated to follow the new standard. Since it would be difficult to rewrite the entire library in one update, the standard will allow for a mix of BFC enabled and non-enabled files in one rendering.

<span id="definitions"></span>

### Definitions

Certified

An LDraw file is certified if it complies with the specifications in this document, includes a 0 BFC CERTIFY meta-statement before the first operational command-line, and does not contain a 0 BFC NOCERTIFY meta-statement.

Clipping

In this document, the term clipping is used as a synonym for culling. While this is technically incorrect, the usage is kept for backwards compatibility with the prior draft and de-facto standards. (In other graphic contexts, clipping usually refers to trimming a geometric primitive to not extend past the edge of a given region, while culling refers to not drawing the primitive at all.)

Culling

In this document, the term culling refers to the process of performing back face culling; that is, not drawing a geometric primitive at all.

File-reference Branch

A set of files in the file-reference tree that either start from the main model file or from a part file. The file-reference tree has a single main branch (the main model) which contains many sub-branches (the parts) which themselves may contain sub-branches (for example, a complete assembly such as a minifig).

Invert

Turning a subfile inside out, usually performed on geometric primitives. When back face culling is used inversion is needed or interior surfaces will never be rendered. Because polygons are one-sided, interior primitives need to have their surfaces face inward, rather than outward.

LDraw file

A single file specifying a part, sub-part, primitive or model. Parts, sub-parts and primitives have the extension DAT, while models can use DAT, LDR or MPD. While BFC meta-statements are rarely used in model files, they still apply, and should be used if the model file contains any polygons.

Operational Command-Line

Any statement in an LDraw file with line-type 1 through 5. In other words, the Subfile, Line, Triangle, Quad, and Conditional Line statements.

Part

An LDraw file which represents a complete real-world building element. These files are stored in the ldraw\\parts\\ directory.

Polygon

A 2D surface created by LDraw's line-type 3 (triangle) or 4 (quadrilateral) command.

Primitive

An LDraw file, typically small, which models a geometric shape or a standard attribute of building elements, such as studs or the cross-axle shape. These files are kept in the ldraw\\p\\ directory (for lo-res primitives) and the ldraw\\p\\48 directory (for hi-res primitives). (In other graphics contexts, the term primitive refers to the basic geometric shapes provided by the rendering environment.)

Subfile

An LDraw file referenced from another file, via a line-type 1 command. Or any file which is lower in the file-reference branch than the current file.

Subpart

An LDraw file which is only a portion of a complete element. It does not necessarily correspond to a discrete portion of a real-world building element. These files are kept in the ldraw\\parts\\s\\ directory.

Superfile

The file which referenced the current file. More generally, any file which is higher in the current file-reference branch than the current file.

Winding

This is the order vertices are specified in a polygon command. The order can be either clockwise or counter-clockwise (AKA anti-clockwise), and is based on viewing the polygon from its front side.

Clockwise winding (vertices numbered 1 through 4):

<img src="https://www.ldraw.org/uploads/images/Articles/quad.jpg" class="ui image" />

Counter-clockwise winding:
 

<img src="https://www.ldraw.org/uploads/images/Articles/quadccw.jpg" class="ui image" />

<span id="functionality"></span>

#### Language Extension Functionality

The BFC language extension allows LDraw files to specify and control the following conditions:

*Compliance*. LDraw files which follow the BFC extension must be clearly and unambiguously marked. It is also useful to allow non-compliant files to be marked as well. Having the compliancy stated plainly simplifies the task of the rendering program, and makes it easier for humans to read files.

Marking a file as BFC-compliant only directly affects that file. In order for subfiles to be treated as compliant, they must also be marked as compliant. Additionally, with the exception of parts, a file is only treated as being BFC-compliant if it and all of its superfiles are compliant. The reason for this is that, while processing, there is no way to know the intended inversion state of a subfile when the file's superfile isn't BFC-compliant. The reason that part files can be excepted from this rule is that they are complex closed solids, so there is never a valid reason to invert them. Assuming part files are never inverted allows the rendering engine to apply BFC-processing on certified parts, even if the calling file(s) (for example, the main model file or sub-models of the main model) aren't certified.

*Winding*. It must be possible for a file to specify the winding order of the polygon commands within that file: clockwise, counterclockwise, or unknown. Allowing the winding to be set at the file level (as part of the 0 BFC CERTIFY meta-statement) is primarily a convenience for file authors.

Changing the winding setting will only affect the current file. It will not modify the winding of subfiles.

It is permitted to change the winding of polygons within a file. In this case the change of winding direction affects all polygons following the CW/CCW option, either until the end of the current file or another CW/CCW option is encountered.

*Culling*. It must be possible to enable and disable culling during the processing of a file. But even when culling is currently enabled, it may not be possible to actually cull the polygons. Polygons can be tested for culling only when the following conditions apply:

- All superfiles (in the current file-reference branch) are certified
- The current file is certified
- No superfile has disabled culling prior to referencing this subfile

Unless all of these conditions are met at the time a subfile is rendered, no culling is possible.

If the culling state is modified, it affects all lines following the CLIP/NOCLIP option, either until the end of the current file or another CLIP/NOCLIP option is encountered. When subfiles are referenced, they will receive a flag indicating the accumulated culling state, but there is no sense of a global culling mode.

*Inversion*. Sometimes, it is desireable to reverse the surfaces of a subfile; to turn the subfile 'inside out'.

One common example of inversion is the cylinder primitive. Cylinder primitives are designed so the surfaces face outward from the center. In 3D tubes, a pair of cylinder primitives are used to model the tube; one outer cylinder is oriented normally, and the inside cylinder, scaled slightly smaller, is required to face inward. This is accomplished by flagging the inner cylinder as being inverted.

Inversion accumulates down the file-reference branch. If the current file is being rendered inverted, then any subfiles of the current file are also rendered as inverted.

Inversion is a boolean operation; inverting a file that is already inverted will give the file the normal orientation. So if the current file is inverted, and a subfile is flagged as inverted, the subfile will be rendered with normal orientation, that is, right-side-out.

(As a practical matter, rendering engines can accomplish inversion simply by switching the order of winding; treat CCW files as CW and vice versa. This must happen in conjunction with the other settings.)

<span id="extensions"></span>

#### Language Extensions

There is a single meta-statement in the BFC language extension, the 0 BFC statement. The statement includes options to specify BFC-related operations.

Syntax:

`0 BFC (NOCERTIFY | CERTIFY [CW|{CCW}])`\
`0 BFC ((CW|CCW) | CLIP [(CW|CCW)] | NOCLIP | INVERTNEXT)`

where (a \| b) means either a or b, \[\] indicates optional items and {} indicates the default value.

This syntax results in the following permissable variations of the BFC meta-statement

`0 BFC NOCERTIFY`\
\
`0 BFC CERTIFY` *(CCW is implied)*\
`0 BFC CERTIFY CW`\
`0 BFC CERTIFY CCW`\
\
`0 BFC CW`\
`0 BFC CCW`\
\
`0 BFC CLIP` *(winding is unchanged)*\
`0 BFC CLIP CW`\
`0 BFC CLIP CCW`\
\
`0 BFC NOCLIP`\
\
`0 BFC INVERTNEXT`

The BFC meta-statement and all of its options are case-sensitive, ie, they must always be in all capitals.

The BFC meta-statement shall ignore repeating whitespace, and accept any number of spaces or tabs as equivalent to a single space.

In order for a file to be processed with back face culling, there must be at least one 0 BFC meta-statement before the first operational command-line. If there is no such 0 BFC meta-statement in the file, BFC processing will be disabled for that file.

Only one NOCERTIFY/CERTIFY meta-statement may be present in a file, and if present, must preceed all other BFC meta-statements and operational command-lines.

All BFC commands that act on succeeding lines in the file shall ignore empty lines.

For backwards compatibility the CLIP and winding options may be specified in any order on the meta-statement, so the following are also valid

`0 BFC CW CLIP`\
`0 BFC CCW CLIP`

<span id="operations"></span>

#### Language Operations

*CERTIFY*

This option indicates the LDraw file is compatible with the back face culling extension. Every LDraw file must be clearly labeled if it is compliant. One way to accomplish this is to place 0 BFC CERTIFY at the beginning of the file, before the first operational command-line.

A second way to specify a file as compliant is to use any option, except for NOCERTIFY, on a 0 BFC meta-statement, before the first operational command-line. This is an acceptable alternative, but the 0 BFC CERTIFY method is recommended and prefered.

Files in the LDraw.org Parts Library, if they are BFC compliant, are required to have an explicit 0 BFC CERTIFY line in their header.

If a file has no 0 BFC meta-statement before the first operational command-line, 0 BFC NOCERTIFY is assumed and BFC processing will be disabled for the file.

*NOCERTIFY*

This option specifies that the file is not compliant with the BFC specification; the polygons are not wound consistently and/or correctly, and/or subfile references are not properly inverted. If the NOCERTIFY option is used, it must appear before any operational command-lines. Any other BFC meta-statements in the file will be ignored.

*CLIP*

This option sets the cull-state to enabled. This allows culling, if all other conditions for culling are met. (While this option should be called CULL, the CLIP form is intentionally being kept for backwards compatibility.)

*NOCLIP*

This option sets the cull-state to disabled. Any subpart or primitive referenced while the cull-state is disabled will not be eligible for culling. (While this option should be called NOCULL, the NOCLIP form is intentionally being kept for backwards compatibility.)

*CLIP/NOCLIP Notes*

There may be any number of changes to the cull-state in a file, although it is recommended that such changes be kept to a minimum.

If neither the CLIP nor NOCLIP option is specified on a 0 BFC meta-statement before the first operational command-line, then that file's cull-state is set to enabled (CLIP).

*CW*

This option sets polygon winding to clockwise.

*CCW*

This option sets polygon winding to counter-clockwise.

*CW/CCW Notes*

There may be any number of changes to the winding direction in a file, although it is recommended that changes to winding are kept to a minimum.

If no winding option is specified for a file, the local winding state will be defaulted to counter-clockwise (CCW).

*INVERTNEXT*

This option inverts a subpart or primitive. It may only be used immediately before a subfile command line \[while intervening blank lines are permitted, they are discouraged for reasons of readability\], and it only influences the immediately following subfile command. It should never be used before a part.

Example:

`0 BFC INVERTNEXT`\
`1 16 0 0 0 1 0 0 0 1 0 0 0 1 somefile.dat`\
`1 16 0 0 0 1 0 0 0 1 0 0 0 1 another.dat`

In this example, somefile.dat would be rendered as inverted while another.dat would not be inverted.

For further information, see "Inversion" in the Language Extension Functionality section.

<span id="library"></span>

#### LDraw Parts Library Guidelines

*(This section gives some suggestions for implementing BFC within the LDraw Parts Library and the impact on the current library. This section may be varied by other specifications (for example, the Parts Library Header specification) and/or the requirements of the Parts Library administrators without affecting the validity of the Back Face Culling specification.)*

The LDraw Parts Library includes all parts, primitives, and subparts distributed with LDraw or in an ldraw.org parts update.

New parts will not be required to be compliant with this extension. They will however be required to carry a 0 BFC meta-statement, indicating either compliance or non-compliance.

New primitives will be required to be certified before being accepted for release.

It is desirable for all files to use the same winding. When possible, files should use counter-clockwise winding. The actual winding for any part is left to the file author. Primitives should always use CCW winding.

Primitives should generally be written so that polygons face outward, or upward. Exceptions are allowed for polygons which model inward- or downward-facing surfaces.

As noted in the language sections, all BFC compliant files in the parts library will have an explicit 0 BFC CERTIFY line in their header.

#### Rendering Engine Guidelines

*(This section gives some suggestions for the design of programs in order to achieve correct renderings. Any program may violate these guidelines if there is another way to achieve a valid rendering.)*

*Matrix Reversals*. Rendering engines will need to correct for orientation matrices which inadvertently or deliberately reverse a subfile.

Normal transformation:

`1 16 0 0 0 1 0 0 0 1 0 0 0 1 somefile.dat`


'Reversed' transformation:

`1 16 0 0 0 1 0 0 0 -1 0 0 0 1 somefile.dat`


If the rendering engine does not detect and adjust for reversed matrices, the winding of all polygons in the subfile will be switched, causing the subfile to be rendered incorrectly.

The typical method of determining that an orientation matrix is reversed is to calculate the determinant of the matrix. If the determinant is negative, then the matrix has been reversed.

The typical way to adjust for matrix reversals is to switch the expected winding of the polygon vertices. That is, if the file specifies the winding as CW and the orientation matrix is reversed, the rendering program would proceed as if the winding is CCW.

The INVERTNEXT option also reverses the winding of the polygons within the subpart or primitive. If the matrix applied to the subpart or primitive has itself been reversed the INVERTNEXT processing is done IN ADDITION TO the automatic inversion - the two effectively cancelling each other out.

*Inverted Subfiles*. Generally, it is not possible to determine that a subfile reference is inverted or normal (which is the reason for the 0 BFC INVERTNEXT meta-statement). In particular, the rendering engine should \*not\* use the determinant of the orientation matrix to determine if the subfile is intended to be inverted (see 'Matrix Reversals', above).

Note: Part files are never inverted as they represent closed solids.

*Uncertified Files*. No assumptions can be made about models which make direct use of primitives or polygon commands, so a rendering engine should not simply treat uncertified model files as certified.

*Culling State*. The rendering engine can default to either allow or disable culling at the start of processing. Presumably, the user will be given the ability to control this state.

*Degenerate Matrices*. Some orientation matrices do not allow calculation of a determinate. This calculation is central to BFC processing. If an orientation matrix for a subfile is degenerate, then culling will not be possible for that subfile.

<span id="processing"></span>

#### Rendering Processing

*(This section presents a possible model for writing the core processing loop in an LDraw/BFC rendering program. Any program may violate this model if there is another way to achieve a valid rendering.)*

All BFC-relevant logic is included while as much other logic (as possible) is excluded. It should not be assumed that this pseudo-code represents the most effecient way to implement BFC.

The function BFC() returns a boolean value, indicating whether a polygon should be rendered or culled. As the nature of this routine does not impact the BFC standard, the logic for BFC() is not included in the following pseudo-code. There is information about BFC processing available from many locations, including lugnet.cad.dev

    Recursive Procedure RenderFile
    Parameters:
      ModelFile string             // File to render
      AccumCull boolean            // global culling value yes/no
      AccumInvert boolean          // current inversion normal/inverted
      AccumTransformMatrix matrix  // current transformation
      Colour integer               // current colour

    Declare
      LocalCull  boolean                        Initial TRUE
      Winding    bivalue(CCW, CW)               Initial CCW
      Certified  trivalue(TRUE, FALSE, UNKNOWN) Initial UNKNOWN
      InvertNext boolean                        Initial FALSE
      Command    DATCommandLine // Structure containing parameters from
                                // a single operational command-line.

    OpenFile(ModelFile)

    Do Until EOF(ModelFile)
       Get Next Command
       If Command.Colour = 16 Then
          Command.Colour = Colour
       ElseIf Command.Colour = 24 Then
          Command.Colour = EdgeColour(Colour)
       End If

       Case Command.LineType
          BFC
            If Certified is UNKNOWN and no Option in Command is NOCERTIFY Then
               Certified = TRUE
            End If

            Do for each Option in Command
               Case Option
                  CERTIFY
                     Assert Certified != FALSE
                        // Triggers error if file has been NOCERTIFY'ed
                     Certified = TRUE
                  NOCERTIFY
                     Assert Certified != TRUE
                        // Triggers error if file has been CERTIFY'ed
                     Certified = FALSE
                  CLIP:   LocalCull = TRUE
                  NOCLIP: LocalCull = FALSE
                  CCW
                     If AccumInvert Then
                        Winding = CW
                     Else
                        Winding = CCW
                  CW
                     If AccumInvert Then
                        Winding = CCW
                     Else
                        Winding = CW
                  INVERTNEXT
                     InvertNext = TRUE
               End Case
            End Do
          SUBFILE
             If Certified is UNKNOWN Then
                Certified = FALSE
             Case Certified
                TRUE
                   RenderFile Command.Subfile,
                        (AccumCull and LocalCull),
                        (AccumInvert xor InvertNext),
                        Command.TransformMatrix * AccumTransformMatrix,
                        Command.Colour
                FALSE, UNKNOWN
                   RenderFile Command.Subfile,
                        FALSE,
                        (AccumInvert xor InvertNext),
                        Command.TransformMatrix * AccumTransformMatrix,
                        Command.Colour
          LINE, CONDITIONAL_LINE
             If Certified is UNKNOWN Then
                Certified = FALSE
             Deal with primitive command
          TRIANGLE, QUAD
             If Certified is UNKNOWN Then
                Certified = FALSE
             End If
             If AccumCull and LocalCull And (Certified is TRUE) Then
                If BFC(Command, AccumTransformMatrix, Winding) Then
                   Render Command
                Else
                   Don't render Command
             Else
                Render Command
             End If
       End Case

       If Command.LineType != BFC Then
          InvertNext = FALSE
       ElseIf No Option in Command is INVERTNEXT Then
          InvertNext = FALSE
       End If
    Loop
    End Procedure

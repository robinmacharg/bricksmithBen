#!/usr/bin/env python3 -I
"""Regenerate scripts/mutations/*.patch from the table below (plan §5 P2 mutation smoke test).

Each entry: (name, file under trunk/Bricksmith/Source, exact text, replacement, occurrence). The text must occur
in the file (occurrence picks which match, 1-based). The patch is made with `git diff` against a clean tree and
the file restored. Re-run after P4 refactors move the code (the plan re-runs the smoke test then).
"""
import os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = "trunk/Bricksmith/Source/"
M = [
 ("utilities-float-precision", "LDraw/Support/LDrawUtilities.m", 'snprintf(formattedFloat, sizeof(formattedFloat), "%f", number);', 'snprintf(formattedFloat, sizeof(formattedFloat), "%.3f", number);', 1),
 ("utilities-float-keep-point", "LDraw/Support/LDrawUtilities.m", "if(*endOfString != '.')", "if(*endOfString == '.')", 1),
 ("utilities-columnized-width", "LDraw/Support/LDrawUtilities.m", '@"%12f", number', '@"%11f", number', 1),
 ("utilities-direct-colour-alpha", "LDraw/Support/LDrawUtilities.m", "components[3] = (GLfloat) 1.0; // alpha", "components[3] = (GLfloat) 0.9; // alpha", 1),
 ("triangle-depth-pick", "LDraw/Commands/LDrawTriangle.m", "if(probe.z <= *bestDepth)", "if(probe.z >= *bestDepth)", 1),
 ("line-write-vertex", "LDraw/Commands/LDrawLine.m", "[LDrawUtilities outputStringForFloat:vertex2.z]", "[LDrawUtilities outputStringForFloat:vertex2.y]", 1),
 ("line-undo-vertex1", "LDraw/Commands/LDrawLine.m", "[[undoManager prepareWithInvocationTarget:self] setVertex1:[self vertex1]];", "", 1),
 ("triangle-parse-z", "LDraw/Commands/LDrawTriangle.m", "workingVertex.z = [parsedField floatValue];", "workingVertex.z = -[parsedField floatValue];", 2),
 ("triangle-collect-normal", "LDraw/Commands/LDrawTriangle.m", "GLfloat n[3] = { normal.x, normal.y, normal.z };", "GLfloat n[3] = { normal.x, normal.y, -normal.z };", 1),
 ("quad-bowtie-swap", "LDraw/Commands/LDrawQuadrilateral.m", "if(V3Dot(cross1, cross4) < 0)", "if(V3Dot(cross1, cross4) > 0)", 1),
 ("condline-write-order", "LDraw/Commands/LDrawConditionalLine.m", "[LDrawUtilities outputStringForFloat:conditionalVertex1.x]", "[LDrawUtilities outputStringForFloat:conditionalVertex2.x]", 1),
 ("part-write-transpose", "LDraw/Commands/LDrawPart.m", "transformation.element[1][0]], //transformationX.y", "transformation.element[0][1]], //transformationX.y", 1),
 ("part-parse-y", "LDraw/Commands/LDrawPart.m", "transformation.element[3][1] = [parsedField floatValue];", "transformation.element[3][1] = -[parsedField floatValue];", 1),
 ("part-name-case", "LDraw/Commands/LDrawPart.m", "[newPartName lowercaseString]", "newPartName", 1),
 ("part-nudge-height", "LDraw/Commands/LDrawPart.m", "V3MulScalar(nudgeVector, 24.0 / 20.0)", "V3MulScalar(nudgeVector, 20.0 / 20.0)", 1),
 ("drawable-snap-floor", "LDraw/Commands/LDrawDrawableElement.m", "position.y = roundf(position.y/gridSpacing) * gridSpacing;", "position.y = floorf(position.y/gridSpacing) * gridSpacing;", 1),
 ("container-insert-index", "LDraw/Files/LDrawContainer.m", "[containedObjects insertObject:directive atIndex:index];", "[containedObjects insertObject:directive atIndex:(index > 0 ? index - 1 : 0)];", 1),
 ("container-remove-index", "LDraw/Files/LDrawContainer.m", "[containedObjects removeObjectAtIndex:index]; //or disowned at least.", "[containedObjects removeObjectAtIndex:0]; //or disowned at least.", 1),
 ("step-write-rel-as-abs", "LDraw/Files/LDrawStep.m", "LDRAW_ROTATION_RELATIVE ];", "LDRAW_ROTATION_ABSOLUTE ];", 1),
 ("step-write-precision", "LDraw/Files/LDrawStep.m", '@"0 %@ %.3f %.3f %.3f %@",LDRAW_ROTATION_STEP_TERMINATOR,', '@"0 %@ %.2f %.3f %.3f %@",LDRAW_ROTATION_STEP_TERMINATOR,', 1),
 ("step-parse-additive", "LDraw/Files/LDrawStep.m", "[self setStepRotationType:LDrawStepRotationAdditive];", "[self setStepRotationType:LDrawStepRotationAbsolute];", 1),
 ("step-parse-default-rel", "LDraw/Files/LDrawStep.m", "else if( [scanner isAtEnd] == YES )\n\t\t\t\t[self setStepRotationType:LDrawStepRotationRelative];", "else if( [scanner isAtEnd] == YES )\n\t\t\t\t[self setStepRotationType:LDrawStepRotationAbsolute];", 1),
 ("model-header-name", "LDraw/Files/LDrawModel.m", '[written appendFormat:@"0 %@ %@%@", LDRAW_HEADER_NAME, [self fileName], CRLF];', '[written appendFormat:@"0 %@  %@%@", LDRAW_HEADER_NAME, [self fileName], CRLF];', 1),
 ("model-step-display-limit", "LDraw/Files/LDrawModel.m", "maxStep = MIN( [steps count] -1 , //subtract one to get last step index in model.", "maxStep = MIN( [steps count] -1 , //subtract one to get last step index in model.\n\t\t\t\t\t   1 +", 1),
 ("mpd-write-start", "LDraw/Files/LDrawMPDModel.m", '[written appendFormat:@"0 %@ %@%@", LDRAW_MPD_SUBMODEL_START, [self modelName], CRLF];', '[written appendFormat:@"0 %@ %@%@", LDRAW_MPD_SUBMODEL_START, [[self modelName] uppercaseString], CRLF];', 1),
 ("colorlibrary-fallback", "LDraw/Support/ColorLibrary.m", "color = [[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor];", "color = [[ColorLibrary sharedColorLibrary] colorForCode:LDrawEdgeColor];", 1),
 ("partlibrary-description-key", "LDraw/Support/PartLibrary.m", "NSDictionary	*partRecord			= [partList				objectForKey:[part referenceName]];", "NSDictionary	*partRecord			= [partList				objectForKey:[[part referenceName] uppercaseString]];", 1),
 ("hidden-not-honoured", "LDraw/Commands/LDrawTriangle.m", "if(self->hidden == NO)", "if(YES)", 4),
 ("triangle-undo-action-name", "LDraw/Commands/LDrawTriangle.m", 'NSLocalizedString(@"UndoAttributesTriangle", nil)', 'NSLocalizedString(@"UndoAttributesLine", nil)', 1),
 ("triangle-move-z", "LDraw/Commands/LDrawTriangle.m", "Point3 newVertex3 = V3Add(self->vertex3, moveVector);", "Point3 newVertex3 = V3Sub(self->vertex3, moveVector);", 1),
]

def main():
    os.chdir(ROOT)
    if subprocess.run(["git", "status", "--porcelain", "--untracked-files=no", SRC], capture_output=True, text=True).stdout.strip():
        sys.exit("source tree not clean")
    out = os.path.join(ROOT, "scripts", "mutations")
    for name, rel, old, new, occ in M:
        path = SRC + rel
        text = open(path, encoding="utf-8", errors="surrogateescape").read()
        i = -1
        for _ in range(occ):
            i = text.find(old, i + 1)
            if i < 0:
                sys.exit(f"{name}: occurrence {occ} of the text not found in {rel}")
        open(path, "w", encoding="utf-8", errors="surrogateescape").write(text[:i] + new + text[i + len(old):])
        diff = subprocess.run(["git", "diff", "--", path], capture_output=True, text=True).stdout
        subprocess.run(["git", "checkout", "--", path], check=True)
        open(os.path.join(out, name + ".patch"), "w").write(diff)
    print(f"wrote {len(M)} patches")

if __name__ == "__main__":
    main()

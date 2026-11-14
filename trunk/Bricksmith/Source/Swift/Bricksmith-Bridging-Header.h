//==============================================================================
//
// File:		Bricksmith-Bridging-Header.h
//
// Purpose:		Exposes Objective-C (and C) headers to Swift. This is the ONLY
//				bridging header: test targets see these types through
//				`@testable import Bricksmith`.
//
//				Every header imported here must be self-contained (it cannot
//				rely on the prefix header). When a class is ported to Swift,
//				remove its header from this list.
//
//==============================================================================

#import "TransformerIntMinus1.h"

// --- LDraw model (P1 header hygiene: group 1) ---
#import "LDrawColor.h"
#import "LDrawComment.h"
#import "LDrawConditionalLine.h"
#import "LDrawDrawableElement.h"
#import "LDrawLSynth.h"
#import "LDrawLSynthDirective.h"
#import "LDrawLine.h"
#import "LDrawMetaCommand.h"
#import "LDrawPart.h"
#import "LDrawQuadrilateral.h"
#import "LDrawTexture.h"
#import "LDrawTriangle.h"
#import "LDrawContainer.h"
#import "LDrawFile.h"
#import "LDrawMPDModel.h"
#import "LDrawModel.h"
#import "LDrawStep.h"
#import "ColorLibrary.h"
#import "ComputationalGeometry.h"
#import "GLMatrixMath.h"
#import "LDrawDirective.h"
#import "LDrawDragHandle.h"
#import "LDrawFastSet.h"
#import "LDrawGLCamera.h"
#import "LDrawGLRenderer.h"
#import "LDrawKeywords.h"
#import "LDrawMovableDirective.h"
#import "LDrawPathNames.h"
#import "LDrawPaths.h"
#import "LDrawUtilities.h"
#import "MatrixMath.h"
#import "ModelManager.h"
#import "OpenGLUtilities.h"
#import "PartCatalogBuilder.h"
#import "PartLibrary.h"
#import "PartReport.h"

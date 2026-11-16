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


// --- LDraw model (P1 header hygiene: group 1) ---
#import "LDrawColor.h"
#import "LDrawDrawableElement.h"
#import "LDrawLSynth.h"
#import "LDrawPart.h"
#import "LDrawContainer.h"
#import "LDrawFile.h"
#import "LDrawStep.h"
#import "ColorLibrary.h"
#import "ComputationalGeometry.h"
#import "GLMatrixMath.h"
#import "LDrawDirective.h"
#import "LDrawRenderer.h"
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

// --- Constants, categories and utilities (group 2) ---
#import "MacLDraw.h"
#import "BricksmithUtilities.h"

// --- Application classes driven by characterisation tests (group 2) ---
#import "LDrawApplication.h"
#import "LDrawDocument.h"
#import "DocumentToolbarController.h"
#import "LDrawFileOutlineView.h"
#import "PartLibraryController.h"
#import "LSynthConfiguration.h"
#import "MinifigureDialogController.h"
#import "PartBrowserDataSource.h"
#import "RelatedParts.h"
#import "SearchPanelController.h"
#import "PieceCountPanel.h"
#import "LDrawColorWell.h"
#import "LDrawColorBar.h"
#import "BackgroundColorView.h"
#import "ArchiveSupport.h"	// ObjC-only exception catching for Swift callers (P5, BUG-035)
#import "OverlayHelperView.h"	// for OverlayViewCategory.swift (P5)

// --- Test support (group 3) ---
#import "BricksmithTestSupport.h"
#import "PreferencesDialogController.h"

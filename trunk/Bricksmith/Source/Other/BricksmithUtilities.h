//==============================================================================
//
// File:		BricksmithUtilities.h
//
// Purpose:		Grid-mode enums shared by the document, toolbar and viewer.
//				The BricksmithUtilities class is in BricksmithUtilities.swift.
//
// Modified:	02/07/2011 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "MatrixMath.h"

// How much parts move when you nudge them in the viewer. 
typedef NS_ENUM(int, gridSpacingModeT)
{
	gridModeFine	= 0,
	gridModeMedium	= 1,
	gridModeCoarse	= 2
	
};

// Are movements aligned to the overall model or the individual selected part.
typedef NS_ENUM(int, gridOrientationModeT)
{
	gridOrientationModel = 0,
	gridOrientationPart = 1
	
};

// The BricksmithUtilities class itself was ported to BricksmithUtilities.swift
// (P5). This header stays for the grid-mode enums above, which ObjC headers
// (LDrawDocument.h, LDrawGLView.h, DocumentToolbarController.h) use and which
// can't come from Bricksmith-Swift.h (plan §4.4 rule 8). ObjC callers of the
// class import "Bricksmith-Swift.h" in their .m files.

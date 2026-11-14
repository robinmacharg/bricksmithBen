//==============================================================================
//
// File:		BricksmithUtilities.h
//
// Purpose:		Miscellaneous utility methods for the Bricksmith application.
//
// Notes:		Utility methods specific to LDraw syntax, manipulation, or 
//				display or found in LDrawUtilities. 
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

////////////////////////////////////////////////////////////////////////////////
//
// BricksmithUtilities
//
////////////////////////////////////////////////////////////////////////////////
@interface BricksmithUtilities : NSObject
{

}

+ (NSImage *) dragImageWithOffset:(NSPointPointer)dragImageOffset;
+ (float) gridSpacingForMode:(gridSpacingModeT)gridMode;

@end

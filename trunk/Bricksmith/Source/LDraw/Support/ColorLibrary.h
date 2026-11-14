//==============================================================================
//
// File:		ColorLibrary.h
//
// Purpose:		A repository of methods, functions, and data types used to 
//				support LDraw colors.
//
// Modified:	2/26/05 Allen Smith. Creation date (LDrawColor.m)
//				3/16/08 Allen Smith. Moved to ColorLibrary as part of 
//							ldconfig.ldr support. 
//
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>

#import "LDrawColor.h"


////////////////////////////////////////////////////////////////////////////////
//
// Protocol:	LDrawColorable
//
// Notes:		This protocol is adopted by classes that accept colors, such as 
//				LDrawPart and LDrawQuadrilateral. 
//
NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////
@protocol LDrawColorable

-(null_unspecified LDrawColor *) LDrawColor;						// unverified (P1 rule): see port-status.md
- (void) setLDrawColor:(null_unspecified LDrawColor *)newColor;

@end


////////////////////////////////////////////////////////////////////////////////
//
// Class:		ColorLibrary
//
////////////////////////////////////////////////////////////////////////////////
@interface ColorLibrary : NSObject
{
	NSMutableDictionary	*colors;		// keys are LDrawColorT codes; objects are LDrawColors
	NSMutableDictionary *privateColors;	// colors we might be asked to display, but should NOT be in the color picker
}

// Initialization
+ (nullable ColorLibrary *) sharedColorLibrary;			// nil if LDConfig.ldr cannot be loaded (S4)

// Accessors
- (NSArray<LDrawColor *> *) colors;
- (nullable LDrawColor *) colorForCode:(LDrawColorT)colorCode;	// falls back to LDrawCurrentColor; nil only without a shared library
- (void) getComplimentRGBA:(GLfloat *)complimentRGBA forCode:(LDrawColorT)colorCode;

// Registering Colors
- (void) addColor:(LDrawColor *)newColor;
- (void) addPrivateColor:(LDrawColor *)newColor;

// Utilities

void complimentColor(const GLfloat *originalColor, GLfloat *complimentColor);

// Test support (do not call from app code)
+ (void) resetForTesting;

@end

NS_ASSUME_NONNULL_END

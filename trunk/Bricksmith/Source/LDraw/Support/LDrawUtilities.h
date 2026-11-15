//==============================================================================
//
// File:		LDrawUtilities.h
//
// Purpose:		Convenience routines for managing LDraw directives: their 
//				syntax, manipulation, or display. 
//
//  Created by Allen Smith on 2/28/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "ColorLibrary.h"
#import "MatrixMath.h"

@class LDrawDirective;
@class LDrawPart;


// Viewing Angle
typedef NS_ENUM(int, ViewOrientationT)
{
	ViewOrientation3D			= 0,
	ViewOrientationFront		= 1,
	ViewOrientationBack			= 2,
	ViewOrientationLeft			= 3,
	ViewOrientationRight		= 4,
	ViewOrientationTop			= 5,
	ViewOrientationBottom		= 6,
	ViewOrientationWalkThrough	= 7
	
};


////////////////////////////////////////////////////////////////////////////////
//
// LDrawUtilities
//
////////////////////////////////////////////////////////////////////////////////
@interface LDrawUtilities : NSObject
{

}

// Configuration
+ (NSString *) defaultAuthor;

+ (void) setColumnizesOutput:(BOOL)flag;
+ (void) setDefaultAuthor:(NSString *)nameIn;

// Parsing
+ (Class) classForDirectiveBeginningWithLine:(NSString *)line;
+ (LDrawColor *) parseColorFromField:(NSString *)colorField;
+ (NSString *) readNextField:(NSString *) partialDirective
				   remainder:(NSString **) remainder;
+ (NSString *) scanQuotableToken:(NSScanner *)scanner;
+ (NSString *) stringFromFile:(NSString *)path;
+ (NSString *) stringFromFileData:(NSData *)fileData;

// Writing
+ (NSString *) outputStringForColor:(LDrawColor *)color;
+ (NSString *) outputStringForFloat:(float)number;

// Hit Detection
+ (void) registerHitForObject:(id)hitObject depth:(float)depth creditObject:(id)creditObject hits:(NSMutableDictionary *)hits;
+ (void) registerHitForObject:(id)hitObject creditObject:(id)creditObject hits:(NSMutableSet *)hits;

// Images
+ (CGImageRef) imageAtPath:(NSString *)imagePath;

// Miscellaneous
+ (Tuple3) angleForViewOrientation:(ViewOrientationT)orientation;
+ (Box3) boundingBox3ForDirectives:(NSArray *)directives;
+ (BOOL) isLDrawFilenameValid:(NSString *)fileName;
+ (void) updateNameForMovedPart:(LDrawPart *)movedPart;
+ (ViewOrientationT) viewOrientationForAngle:(Tuple3)rotationAngle;
+ (void) unresolveLibraryParts:(LDrawDirective *)directive;

// Test support (do not call from app code)
+ (void) resetForTesting;

@end

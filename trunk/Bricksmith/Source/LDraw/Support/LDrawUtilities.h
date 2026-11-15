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
NS_ASSUME_NONNULL_BEGIN

@interface LDrawUtilities : NSObject
{

}

// Configuration
+ (null_unspecified NSString *) defaultAuthor;

+ (void) setColumnizesOutput:(BOOL)flag;
+ (void) setDefaultAuthor:(null_unspecified NSString *)nameIn;

// Parsing
+ (nullable Class) classForDirectiveBeginningWithLine:(null_unspecified NSString *)line;	// Nil for unknown line codes (BUG-001)
+ (null_unspecified LDrawColor *) parseColorFromField:(null_unspecified NSString *)colorField;
+ (null_unspecified NSString *) readNextField:(null_unspecified NSString *) partialDirective
				   remainder:(NSString * _Null_unspecified * _Null_unspecified) remainder;
+ (null_unspecified NSString *) scanQuotableToken:(null_unspecified NSScanner *)scanner;
+ (null_unspecified NSString *) stringFromFile:(null_unspecified NSString *)path;
+ (nullable NSString *) stringFromFileData:(nullable NSData *)fileData;	// nil only for nil data (falls back UTF-8 -> Latin-1 -> MacRoman)

// Writing
+ (null_unspecified NSString *) outputStringForColor:(null_unspecified LDrawColor *)color;
+ (null_unspecified NSString *) outputStringForFloat:(float)number;

// Hit Detection
+ (void) registerHitForObject:(null_unspecified id)hitObject depth:(float)depth creditObject:(null_unspecified id)creditObject hits:(null_unspecified NSMutableDictionary *)hits;
+ (void) registerHitForObject:(null_unspecified id)hitObject creditObject:(null_unspecified id)creditObject hits:(null_unspecified NSMutableSet *)hits;

// Images
+ (null_unspecified CGImageRef) imageAtPath:(null_unspecified NSString *)imagePath;

// Miscellaneous
+ (Tuple3) angleForViewOrientation:(ViewOrientationT)orientation;
+ (Box3) boundingBox3ForDirectives:(null_unspecified NSArray *)directives;
+ (BOOL) isLDrawFilenameValid:(null_unspecified NSString *)fileName;
+ (void) updateNameForMovedPart:(null_unspecified LDrawPart *)movedPart;
+ (ViewOrientationT) viewOrientationForAngle:(Tuple3)rotationAngle;
+ (void) unresolveLibraryParts:(null_unspecified LDrawDirective *)directive;

// Test support (do not call from app code)
+ (void) resetForTesting;

@end

NS_ASSUME_NONNULL_END

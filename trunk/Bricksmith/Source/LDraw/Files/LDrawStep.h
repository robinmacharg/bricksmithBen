//==============================================================================
//
// File:		LDrawStep.h
//
// Purpose:		Represents a collection of Lego bricks which compose a single 
//				step when constructing a model.
//
//  Created by Allen Smith on 2/20/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "ColorLibrary.h"
#import "LDrawContainer.h"

// This notification is sent by steps when step-specific meta-data (e.g. the viewing
// angle changes.  It is only sent when notification is legal to avoid GCD threading
// problems.  If the step changes by a directive being inserted the more generic
// LDrawDirectiveDidChangeNotification is sent out by the base container class.
#define LDrawStepDidChangeNotification				@"LDrawStepDidChangeNotification"

@class LDrawModel;

////////////////////////////////////////////////////////////////////////////////
//
// Types & Constants
//
////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(int, LDrawStepRotationT)
{
	LDrawStepRotationNone		= 0,	// inherit previous step rotation (or default view)
	LDrawStepRotationRelative	= 1,	// rotate relative to default 3D viewing angle
	LDrawStepRotationAbsolute	= 2,	// rotate relative to (0, 0, 0)
	LDrawStepRotationAdditive	= 3,	// rotate relative to the previous step's rotation
	LDrawStepRotationEnd		= 4		// cancel the effect of the previous rotation

};


//Describes the contents of this step.
typedef NS_ENUM(int, LDrawStepFlavorT)
{
	LDrawStepAnyDirectives,		//step can hold any type of subdirectives.
	LDrawStepLines,				//step can hold *only* LDrawLines.
	LDrawStepTriangles,			// etc.
	LDrawStepQuadrilaterals,	// etc.
	LDrawStepConditionalLines	// etc.
	
};


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawStep
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawStep : LDrawContainer
{
	LDrawStepRotationT	stepRotationType;
	Tuple3				rotationAngle;		// in degrees
	Box3				cachedBounds;		// cached bounds of the step
	//Optimization variables
	LDrawStepFlavorT	stepFlavor; //defaults to LDrawStepAnyDirectives
	LDrawColorT			colorOfAllDirectives;
	
	//Inherited from the superclasses:
	//NSMutableArray	*containedObjects; //the commands that make up the step.
	//LDrawContainer	*enclosingDirective; //weak link to enclosing model.
}

//Initialization
+ (null_unspecified id) emptyStep;
+ (null_unspecified id) emptyStepWithFlavor:(LDrawStepFlavorT) flavorType;

//Directives
- (null_unspecified NSString *) writeWithStepCommand:(BOOL) flag;

//Accessors
- (null_unspecified LDrawModel *) enclosingModel;
- (Tuple3) rotationAngle;
- (Tuple3) rotationAngleZYX;
- (LDrawStepFlavorT) stepFlavor;
- (LDrawStepRotationT) stepRotationType;

- (void) setModel:(null_unspecified LDrawModel *)enclosingModel;
- (void) setRotationAngle:(Tuple3)newAngle;
- (void) setRotationAngleZYX:(Tuple3)newAngleZYX;
- (void) setStepFlavor:(LDrawStepFlavorT)newFlavor;
- (void) setStepRotationType:(LDrawStepRotationT)newValue;

//Utilities
+ (BOOL) lineIsStepTerminator:(null_unspecified NSString*)line;
+ (BOOL) lineIsRotationStepTerminator:(null_unspecified NSString*)line;
- (BOOL) parseRotationStepFromLine:(null_unspecified NSString *)rotstep;

@end

NS_ASSUME_NONNULL_END

//==============================================================================
//
// File:		LDrawModel.h
//
// Purpose:		Represents a collection of Lego bricks that form a single model.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawContainer.h"
@class ColorLibrary;
@class LDrawFile;
@class LDrawStep;

////////////////////////////////////////////////////////////////////////////////
//
// class LDrawModel
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawModel : LDrawContainer <NSCoding>
{	
	NSString				*modelDescription;
	NSString				*fileName;
	NSString				*author;
	Point3					rotationCenter;
	
	ColorLibrary			*colorLibrary;			// in-scope !COLOURS local to the model
	BOOL					 stepDisplayActive;		// YES if we are only display steps 1-currentStepDisplayed
	NSUInteger				 currentStepDisplayed;	// display up to and including this step index
	
	Box3					cachedBounds;			// bounds of the model - only covers steps that are showing
	
	//steps are stored in the superclass.
	
	// Drag and Drop
	LDrawStep				*draggingDirectives;
	
	BOOL					isOptimized;			// Were we ever structure-optimized - used to optimize out 
													// some drawing on library parts.
	LDrawDLHandle			dl;						// Cached DL if we have one.
	LDrawDLCleanup_f		dl_dtor;
}

//Initialization
+ (null_unspecified id) model NS_SWIFT_NAME(model());	// factory: keep distinct from -init (LEARNINGS L40)

//Accessors
- (null_unspecified NSString *) category;
- (null_unspecified ColorLibrary *) colorLibrary;
- (null_unspecified NSArray *) draggingDirectives;
- (null_unspecified LDrawFile *)enclosingFile;
- (null_unspecified NSString *)modelDescription;
- (null_unspecified NSString *)fileName;
- (null_unspecified NSString *)author;
- (NSUInteger) maximumStepIndexForStepDisplay;
- (Tuple3) rotationAngleForStepAtIndex:(NSUInteger)stepNumber;
- (Point3) rotationCenter;
- (BOOL) stepDisplay;
- (null_unspecified NSArray *) steps;
- (null_unspecified LDrawStep *) visibleStep;

- (void) setDraggingDirectives:(null_unspecified NSArray *)directives;
- (void) setModelDescription:(null_unspecified NSString *)newDescription;
- (void) setFileName:(null_unspecified NSString *)newName;
- (void) setAuthor:(null_unspecified NSString *)newAuthor;
- (void) setRotationCenter:(Point3)newPoint;
- (void) setStepDisplay:(BOOL)flag;
- (void) setMaximumStepIndexForStepDisplay:(NSUInteger)stepIndex;

//Actions
- (null_unspecified LDrawStep *) addStep;
- (void) addStep:(null_unspecified LDrawStep *)newStep;
- (void) makeStepVisible:(null_unspecified LDrawStep *)step;

//Utilities
- (NSUInteger) maxStepIndexToOutput;
- (NSUInteger) numberElements;
- (void) optimizeStructure;
- (NSUInteger) parseHeaderFromLines:(null_unspecified NSArray *)lines beginningAtIndex:(NSUInteger)index;
- (BOOL) line:(null_unspecified NSString *)line isValidForHeader:(null_unspecified NSString *)headerKey info:(NSString * _Null_unspecified * _Null_unspecified)infoPtr;

@end

NS_ASSUME_NONNULL_END

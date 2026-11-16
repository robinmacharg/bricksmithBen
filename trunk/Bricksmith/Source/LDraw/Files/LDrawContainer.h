//==============================================================================
//
// File:		LDrawContainer.m
//
// Purpose:		Abstract subclass for LDrawDirectives which represent a 
//				collection of related directives.
//
//  Created by Allen Smith on 3/31/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"
#import "MatrixMath.h"

@class PartReport;

////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawContainer
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawContainer : LDrawDirective <NSCoding, NSCopying, LDrawObserver>
{
	@protected
	BOOL				postsNotifications;	// subclasses (LDrawStep, LDrawFile) read it directly; Swift uses the property
	
	@private
	NSMutableArray		*containedObjects;
}

// Implemented by -postsNotifications; set with -setPostsNotifications:, which also applies the flag to the children.
@property (nonatomic, readonly) BOOL postsNotifications;

//Accessors
- (null_unspecified NSArray *) allEnclosedElements;
- (Box3) projectedBoundingBoxWithModelView:(Matrix4)modelView
								projection:(Matrix4)projection
									  view:(Box2)viewport;
- (NSInteger) indexOfDirective:(null_unspecified LDrawDirective *)directive;
- (null_unspecified NSMutableArray *) subdirectives;

- (void) setPostsNotifications:(BOOL)flag;
- (void) setSubdirectiveSelected:(BOOL)flag;

//Actions
- (void) addDirective:(null_unspecified LDrawDirective *)directive;
- (void) collectPartReport:(null_unspecified PartReport *)report;
- (void) applyToAllParts:(null_unspecified LDrawPartVisitor) visitor;
- (void) insertDirective:(null_unspecified LDrawDirective *)directive atIndex:(NSInteger)index;
- (void) removeDirective:(null_unspecified LDrawDirective *)doomedDirective;
- (void) removeDirectiveAtIndex:(NSInteger)index;

- (BOOL) acceptsDroppedDirective:(null_unspecified LDrawDirective *)directive;

@end

NS_ASSUME_NONNULL_END

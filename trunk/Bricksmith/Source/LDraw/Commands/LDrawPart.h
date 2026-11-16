//==============================================================================
//
// File:		LDrawPart.h
//
// Purpose:		Part command.
//				Inserts a part defined in another LDraw file.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>
#import "BricksmithBuildConfig.h"
#import <OpenGL/gl.h>

#import "ColorLibrary.h"
#import "LDrawDirective.h"
#import "LDrawDrawableElement.h"
#import "MatrixMath.h"

@class LDrawFile;
@class LDrawModel;
@class LDrawStep;
@class PartReport;

typedef NS_ENUM(int, PartTypeT) {
	PartTypeUnresolved = 0,	// We have not yet tried to figure out what we have.
	PartTypeNotFound,		// We went looking and the part is missing.  This keeps us from retrying on every query until someone tells us to try again.
	PartTypeLibrary,		// Part is in the library.
	PartTypeSubmodel,		// Part is an MPD submodel from our parent LDrawFile
	PartTypePeerFile		// Part is the first model in another file in the same directory as us.
};


////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawPart
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawPart : LDrawDrawableElement <NSCoding, LDrawObserver>
{
@private
	NSString		*displayName;
	NSString		*referenceName; //lower-case version of display name
	
	GLfloat			glTransformation[16];

	__unsafe_unretained LDrawDirective	*cacheDrawable;			// The drawable is the model we link to OR a VBO that represents it from the part library -- a drawable proxy.
	__unsafe_unretained LDrawModel		*cacheModel;	// both unretained, as under MRC: the part observes the model (L77)			// The model is the real model we link to.
	PartTypeT		cacheType;
	NSLock			*drawLock;
	
	Box3			cacheBounds;			// Cached bonuding box of resolved parts, in part's coordinate (that is, _not_ in the coordinates of the underlying model.
}

//Directives
- (void) drawBoundsWithColor:(null_unspecified LDrawColor *)drawingColor;
- (null_unspecified NSString *) write;

//Accessors
- (null_unspecified NSString *) displayName;
- (Point3) position;
- (null_unspecified NSString *) referenceName;
- (null_unspecified LDrawModel *) referencedMPDSubmodel;
- (null_unspecified LDrawModel *) referencedPeerFile;
- (TransformComponents) transformComponents;
- (Matrix4) transformationMatrix;
- (void) setDisplayName:(null_unspecified NSString *)newPartName;
- (void) setDisplayName:(null_unspecified NSString *)newPartName parse:(BOOL)shouldParse inGroup:(null_unspecified dispatch_group_t)parentGroup;
- (void) setTransformComponents:(TransformComponents)newComponents;
- (void) setTransformationMatrix:(null_unspecified Matrix4 *)newMatrix;

//Actions
- (void) collectPartReport:(null_unspecified PartReport *)report;
- (void) applyToAllParts:(null_unspecified LDrawPartVisitor) visitor;

- (TransformComponents) componentsSnappedToGrid:(float) gridSpacing minimumAngle:(float)degrees;
- (TransformComponents) components:(TransformComponents)components snappedToGrid:(float)gridSpacing minimumAngle:(float)degrees;
- (void) rotateByDegrees:(Tuple3)degreesToRotate;
- (void) rotateByDegrees:(Tuple3)degreesToRotate centerPoint:(Point3)center;

//Utilities
- (BOOL) partIsMissing;

- (void) resolvePart;
- (void) unresolvePart;
- (void) unresolvePartIfPartLibrary;
- (void) followRedirectionAndUpdate;


@end

NS_ASSUME_NONNULL_END

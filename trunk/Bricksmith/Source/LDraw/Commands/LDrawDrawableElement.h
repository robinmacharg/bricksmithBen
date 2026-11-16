//==============================================================================
//
// File:		LDrawDrawableElement.h
//
// Purpose:		Abstract superclass for all LDraw elements that can actually be 
//				drawn (polygons and parts).
//
//  Created by Allen Smith on 4/20/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "ColorLibrary.h"
#import "LDrawDirective.h"
#import "MatrixMath.h"
#import "LDrawMovableDirective.h"

typedef struct
{
	GLfloat position[3];
	GLfloat normal[3];
	GLfloat color[4];
	
} VBOVertexData;

////////////////////////////////////////////////////////////////////////////////
//
// class LDrawDrawableElement
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawDrawableElement : LDrawDirective <LDrawColorable, NSCoding, LDrawMovableDirective>
{
	LDrawColor  *color;
	BOOL        hidden;		//YES if we don't draw this.
}

// Directives
- (null_unspecified VBOVertexData *) writeToVertexBuffer:(null_unspecified VBOVertexData *)vertexBuffer parentColor:(null_unspecified LDrawColor *)parentColor wireframe:(BOOL)wireframe;
- (null_unspecified VBOVertexData *) writeElementToVertexBuffer:(null_unspecified VBOVertexData *)vertexBuffer withColor:(null_unspecified LDrawColor *)drawingColor wireframe:(BOOL)wireframe;


// Accessors
- (Box3) projectedBoundingBoxWithModelView:(Matrix4)modelView
								projection:(Matrix4)projection
									  view:(Box2)viewport;
- (BOOL) isHidden;
- (Point3) position;

- (void) setHidden:(BOOL)flag;

// Actions
//- (Vector3) displacementForNudge:(Vector3)nudgeVector;
//- (void) moveBy:(Vector3)moveVector;
- (Point3) position:(Point3)position snappedToGrid:(float)gridSpacing;

@end

// P6a hot-path seam for Swift subclasses (removed when this class is ported, P6c).
// Swift can't read `hidden`/`color`, and the getters cost two message sends and a retain per
// primitive in -collectSelf:. Returns NO if the element is hidden. Otherwise sets *outColor to
// the colour argument for the collector exactly as the ObjC primitives chose it: current colour
// (16) -> LDrawRenderCurrentColor, edge colour (24) -> LDrawRenderComplimentColor, anything else
// -> `scratch` filled by -getColorRGBA: (left untouched for a nil colour).
FOUNDATION_EXPORT BOOL LDrawDrawableElementCollectorColor(LDrawDrawableElement *element, GLfloat *scratch,
														  GLfloat * _Nullable * _Nonnull outColor);

NS_ASSUME_NONNULL_END

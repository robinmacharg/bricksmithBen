// Ported to LDrawDrawableElement.swift (P6c).
//
// Types-only header: VBOVertexData (vertex-buffer layout used by ObjC and Swift)
// and the imports its users relied on.
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

@class LDrawDrawableElement;

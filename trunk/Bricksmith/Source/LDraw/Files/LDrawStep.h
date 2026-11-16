//==============================================================================
//
// File:		LDrawStep.h
//
// Purpose:		Types-only header. The class LDrawStep is in LDrawStep.swift
//				(ported in P6b); ObjC code gets its interface from
//				Bricksmith-Swift.h. This header keeps the notification name, the
//				two step enums and the imports and forward declarations that
//				importing headers rely on.
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
@class LDrawStep;

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

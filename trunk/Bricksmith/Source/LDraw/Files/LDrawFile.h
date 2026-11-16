//==============================================================================
//
// File:		LDrawFile.h
//
// Purpose:		Types-only header. The class LDrawFile is in LDrawFile.swift
//				(ported in P6a); ObjC code gets its interface from
//				Bricksmith-Swift.h. This header keeps the notification name and
//				the forward declarations that importing headers rely on.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>

#import "LDrawDirective.h"
#import "LDrawContainer.h"

// forward declarations
@class LDrawMPDModel;
@class LDrawFile;


//Active model changed.
// Object is the LDrawFile in which the model resides. No userInfo.
#define LDrawFileActiveModelDidChangeNotification		@"LDrawFileActiveModelDidChangeNotification"

//==============================================================================
//
// File:		MinifigureDialogController.m
//
// Purpose:		Handles the Minifigure Generator dialog.
//
//  Created by Allen Smith on 7/2/06.
//  Copyright 2006. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

@class LDrawMPDModel;

NS_ASSUME_NONNULL_BEGIN

@interface MinifigureDialogController : NSObject

//Accessors
- (null_unspecified LDrawMPDModel *) minifigure;

//Actions
- (NSInteger) runModal;

@end

NS_ASSUME_NONNULL_END

//==============================================================================
//
// File:		BezierPathCategory.h
//
// Purpose:		Handy Bezier path methods Apple forgot.
//
//  Created by Allen Smith on 6/11/07.
//  Copyright 2007. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN

@interface NSBezierPath (BezierPathCategory)

+ (null_unspecified NSBezierPath *) bezierPathWithRect:(NSRect)rect radiusPercentage:(CGFloat)radiusPercentage;

@end

NS_ASSUME_NONNULL_END

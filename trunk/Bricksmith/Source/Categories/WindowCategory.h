//==============================================================================
//
// Category: WindowCategory.h
//
//		Convenient window utility methods.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN

@interface NSWindow (WindowCategory)

- (NSRect) frameRectForContentSize:(NSSize)newSize;
- (void) resizeToSize:(NSSize)newSize animate:(BOOL)animate;

@end

NS_ASSUME_NONNULL_END

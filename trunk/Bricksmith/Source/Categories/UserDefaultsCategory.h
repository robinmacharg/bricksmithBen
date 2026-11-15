//==============================================================================
//
// Category: UserDefaultsCategory.h
//
//		Convenient window utility methods.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface NSUserDefaults (UserDefaultsCategory)

- (void)setColor:(null_unspecified NSColor *)aColor forKey:(null_unspecified NSString *)aKey;
- (nullable NSColor *)colorForKey:(null_unspecified NSString *)aKey;	// nil if absent or not a non-keyed NSArchiver blob (BUG-002)

@end

NS_ASSUME_NONNULL_END

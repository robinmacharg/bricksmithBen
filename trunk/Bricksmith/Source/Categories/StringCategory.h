//==============================================================================
//
// File:		StringCategory.h
//
// Purpose:		Handy string utilities.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface NSString (StringCategory)

- (BOOL) ams_containsString:(null_unspecified NSString *)substring options:(NSUInteger)mask;
+ (null_unspecified NSString *) CRLF;
- (NSComparisonResult)numericCompare:(null_unspecified NSString *)string;
- (null_unspecified NSArray *) separateByLine;
- (null_unspecified NSString *) ams_stringByRemovingWhitespace;

@end

NS_ASSUME_NONNULL_END
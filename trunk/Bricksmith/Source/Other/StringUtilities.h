//==============================================================================
//
// File:		StringUtilities.h
//
// Purpose:		General string utility methods.
//
// Modified:	12/21/2008 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN

@interface StringUtilities : NSObject
{

}

+ (null_unspecified NSString *) nextCopyNameForString:(null_unspecified NSString *)originalString;
+ (null_unspecified NSString *) nextCopyPathForFilePath:(null_unspecified NSString *)basePath;

@end

NS_ASSUME_NONNULL_END

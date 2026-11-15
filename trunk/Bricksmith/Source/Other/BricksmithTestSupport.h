//==============================================================================
//
// File:		BricksmithTestSupport.h
//
// Purpose:		TEST SUPPORT ONLY. Swift cannot catch Objective-C exceptions; an
//				exception thrown on a Swift Testing thread is swallowed by AppKit
//				and the test silently hangs (LEARNINGS L57). Tests run risky ObjC
//				calls through +catchException: and turn the result into a normal
//				test failure.
//
//==============================================================================
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BricksmithTestSupport : NSObject

// Runs block; returns the NSException it raised, or nil if it completed normally.
+ (nullable NSException *) catchException:(NS_NOESCAPE void (^)(void))block;

@end

NS_ASSUME_NONNULL_END

//==============================================================================
//
// File:		BricksmithTestSupport.m
//
// Purpose:		TEST SUPPORT ONLY. See BricksmithTestSupport.h.
//
//==============================================================================
#import "BricksmithTestSupport.h"

@implementation BricksmithTestSupport

+ (nullable NSException *) catchException:(NS_NOESCAPE void (^)(void))block
{
	@try
	{
		block();
	}
	@catch(NSException *exception)
	{
		return exception;
	}
	return nil;
}

@end

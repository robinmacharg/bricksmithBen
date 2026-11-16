//==============================================================================
//
// File:		ArchiveSupport.m
//
// Purpose:		See ArchiveSupport.h.
//
//==============================================================================
#import "ArchiveSupport.h"


//---------- BricksmithUnarchiveObject -----------------------------------------
//
// Purpose:		Unarchives non-keyed NSArchiver data without letting an
//				exception escape. Callers that have nil data get nil, as
//				+[NSUnarchiver unarchiveObjectWithData:nil] returned.
//
//------------------------------------------------------------------------------
id BricksmithUnarchiveObject(NSData *data)
{
	if(data == nil)
		return nil;
	
	@try
	{
		return [NSUnarchiver unarchiveObjectWithData:data];
	}
	@catch(NSException *exception)
	{
		return nil;
	}
}

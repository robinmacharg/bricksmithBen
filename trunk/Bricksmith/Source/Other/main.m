//==============================================================================
//
// File:		main.m
//
// Purpose:		From Allen with love.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "LDrawApplication.h"

int main(int argc, char *argv[])
{
	// Before NSApplicationMain loads any nib: nibs refer to these by name.
	@autoreleasepool
	{
		[LDrawApplication registerValueTransformers];
	}

    return NSApplicationMain(argc, (const char **) argv);
}

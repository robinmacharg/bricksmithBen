//==============================================================================
//
// File:		LDrawMetaCommand.m
//
// Purpose:		Basic holder for a meta-command.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDirective.h"


////////////////////////////////////////////////////////////////////////////////
//
// Class:		LDrawMetaCommand
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawMetaCommand : LDrawDirective
{
	NSString		*commandString;
}

// Initialization
- (BOOL) finishParsing:(null_unspecified NSScanner *)scanner;

// Directives
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(null_unspecified LDrawColor *)parentColor;
- (null_unspecified NSString *) write;

//Accessors
-(void) setStringValue:(null_unspecified NSString *)newString;
-(null_unspecified NSString *) stringValue;

@end

NS_ASSUME_NONNULL_END

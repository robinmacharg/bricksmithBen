//==============================================================================
//
// File:		LDrawMetaCommand.m
//
// Purpose:		Meta-command holder.
//				Could do just about anything, but only in subclasses!
//
//				Line format:
//				0 command... 
//
//				where
//
//				* command is a string; it could mean anything. We have specific 
//				subclasses to deal with recognized meta-commands. This class is 
//				the fallback class for unrecognized commands. 
//
//  Created by Allen Smith on 2/21/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawMetaCommand.h"

#import "LDrawColor.h"
#import "LDrawComment.h"
#import "LDrawKeywords.h"
#import "LDrawTexture.h"
#import "LDrawUtilities.h"


//---------- LogFatallyInvalidMetaCommand ---------------------------[static]--
//
// Purpose:		Logs a meta-command line that could not be parsed. (These are 
//				the messages the parser logged when it used exceptions.) 
//
//------------------------------------------------------------------------------
static void LogFatallyInvalidMetaCommand(NSString *line)
{
	NSLog(@"the meta-command %@ was fatally invalid", line);
	NSLog(@" raised exception %@", @"BricksmithParseException");
}


@implementation LDrawMetaCommand


#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Initialize an empty command.
//
//==============================================================================
- (id) init
{
	self = [super init];
	[self setStringValue:@""];
	return self;
	
}//end init


//---------- directiveWithLines:inRange:parentGroup: ----------------[static]--
//
// Purpose:		Returns the LDraw directive based on lineFromFile, a single line 
//				of LDraw code from a file.
//
//				directive should have the format:
//
//				0 command... 
//
//				This method determines and returns a subclass instance for known 
//				meta-commands (LDrawComment, LDrawColor). Anything else becomes 
//				a generic instance of the receiving class that records the text. 
//
// Notes:		This replaces -initWithLines:inRange:parentGroup:, which used to 
//				return a substitute object. 
//
//------------------------------------------------------------------------------
+ (LDrawDirective *) directiveWithLines:(NSArray *)lines
								inRange:(NSRange)range
							parentGroup:(dispatch_group_t)parentGroup
{
	LDrawMetaCommand	*directive		= nil;
	NSString			*parsedField	= nil;
	NSString			*firstLine		= [lines objectAtIndex:range.location];
	NSScanner			*scanner		= [NSScanner scannerWithString:firstLine];
	int 				lineCode		= 0;
	BOOL				gotLineCode 	= 0;
	int 				metaLineStart	= 0;
	
	[scanner setCharactersToBeSkipped:nil];
	
	// skip leading whitespace
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
	
	//Read in the line code and advance past it.
	gotLineCode = [scanner scanInt:&lineCode];
	
	if(gotLineCode == YES && lineCode == 0)
	{
		// The first word of a meta-command should indicate the command 
		// itself, and thus the syntax of the rest of the line. However, the 
		// first word might not be a recognized command. It might not even 
		// be anything. "0\n" is perfectly valid LDraw.
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		metaLineStart = [scanner scanLocation];
		
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&parsedField];
	
		// Comment?
		if(		[parsedField isEqualToString:LDRAW_COMMENT_SLASH]
		   ||	[parsedField isEqualToString:LDRAW_COMMENT_WRITE]
		   ||   [parsedField isEqualToString:LDRAW_COMMENT_PRINT]    )
		{
			directive = [[LDrawComment alloc] init];
		}
		// Color Definition?
		else if([parsedField isEqualToString:LDRAW_COLOR_DEFINITION])
		{
			directive = [[LDrawColor alloc] init];
		}
		
		// If we recognized the metacommand, use the subclass to finish 
		// parsing. 
		if(directive != nil)
		{
			// On a syntax error the partly-parsed directive is still returned 
			// (KNOWN-BUGS S1); only the log reports the failure. 
			if([directive finishParsing:scanner] == NO)
				LogFatallyInvalidMetaCommand([lines objectAtIndex:range.location]);
		}
		else
		{
			// Didn't specifically recognize this metacommand. Create a 
			// non-functional generic command to record its existence. 
			directive = [[self alloc] init];
			NSString *command = [[scanner string] substringFromIndex:metaLineStart];
	
			[directive setStringValue:command];
		}
	}
	else if(gotLineCode == NO)
	{
		// This is presumably an empty line, and the following will 
		// incorrectly add a 0 linetype to it. 
		directive = [[self alloc] init];
		NSString *command = [scanner string];

		[directive setStringValue:command];
	}
	else
	{
		// nonzero linetype! No directive is returned (KNOWN-BUGS S6).
		LogFatallyInvalidMetaCommand([lines objectAtIndex:range.location]);
	}
	
	return directive;
	
}//end directiveWithLines:inRange:parentGroup:


//========== initWithCoder: ====================================================
//
// Purpose:		Reads a representation of this object from the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	commandString	= [decoder decodeObjectForKey:@"commandString"];
	
	return self;
	
}//end initWithCoder:


//========== encodeWithCoder: ==================================================
//
// Purpose:		Writes a representation of this object to the given coder,
//				which is assumed to always be a keyed decoder. This allows us to 
//				read and write LDraw objects as NSData.
//
//==============================================================================
- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	[encoder encodeObject:commandString forKey:@"commandString"];
	
}//end encodeWithCoder:


//========== copyWithZone: =====================================================
//
// Purpose:		Returns a duplicate of this file.
//
//==============================================================================
- (id) copyWithZone:(NSZone *)zone
{
	LDrawMetaCommand *copied = (LDrawMetaCommand *)[super copyWithZone:zone];
	
	[copied setStringValue:[self stringValue]];
	
	return copied;
	
}//end copyWithZone:


//========== finishParsing: ====================================================
//
// Purpose:		Subclasses override this method to finish parsing their specific 
//				syntax once +[LDrawMetaCommand directiveWithLines:inRange:parentGroup:] 
//				has determined which subclass to instantiate. 
//
// Returns:		YES on success; NO on a syntax error.
//
//==============================================================================
- (BOOL) finishParsing:(NSScanner *)scanner
{
	// LDrawMetaCommand itself doesn't have any special syntax, so we shouldn't 
	// be getting any in this method. 
	return NO;
	
}//end finishParsing:


#pragma mark -
#pragma mark DIRECTIVES
#pragma mark -

//========== draw:viewScale:parentColor: =======================================
//
// Purpose:		Draws the part.
//
//==============================================================================
- (void) draw:(NSUInteger)optionsMask viewScale:(float)scaleFactor parentColor:(LDrawColor *)parentColor

{
	// Nothing to do here.
	
}//end draw:viewScale:parentColor:


//========== write =============================================================
//
// Purpose:		Returns a line that can be written out to a file.
//				Line format:
//				0 command... 
//
//==============================================================================
- (NSString *) write
{
	return [NSString stringWithFormat:
				@"0 %@",
				[self stringValue]
				
			];
}//end write

#pragma mark -
#pragma mark DISPLAY
#pragma mark -

//========== browsingDescription ===============================================
//
// Purpose:		Returns a representation of the directive as a short string 
//				which can be presented to the user.
//
//==============================================================================
- (NSString *) browsingDescription
{
//	return NSLocalizedString(@"Unknown Metacommand", nil);
	return commandString;
	
}//end browsingDescription


//========== iconName ==========================================================
//
// Purpose:		Returns the name of image file used to display this kind of 
//				object, or nil if there is no icon.
//
//==============================================================================
- (NSString *) iconName
{
	return @"Unknown";
	
}//end iconName


//========== inspectorClassName ================================================
//
// Purpose:		Returns the name of the class used to inspect this one.
//
//==============================================================================
- (NSString *) inspectorClassName
{
	return @"InspectionUnknownCommand";
	
}//end inspectorClassName


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== setStringValue: ===================================================
//
// Purpose:		updates the basic command string.
//
//==============================================================================
-(void) setStringValue:(NSString *)newString
{
	
	commandString = newString;
	
}//end setStringValue:


//========== stringValue =======================================================
//
// Purpose:		
//
//==============================================================================
-(NSString *) stringValue
{
	return commandString;
	
}//end stringValue

#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== registerUndoActions ===============================================
//
// Purpose:		Registers the undo actions that are unique to this subclass, 
//				not to any superclass.
//
//==============================================================================
- (void) registerUndoActions:(NSUndoManager *)undoManager
{
	[super registerUndoActions:undoManager];
	
	[[undoManager prepareWithInvocationTarget:self] setStringValue:[self stringValue]];
	
	//[undoManager setActionName:NSLocalizedString(@"UndoAttributesLine", nil)];
	// (unused for this class; a plain "Undo" will probably be less confusing.)
	
}//end registerUndoActions:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Embraced by the light.
//
//==============================================================================
//end dealloc

@end

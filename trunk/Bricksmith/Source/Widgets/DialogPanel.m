//==============================================================================
//
// File:		DialogPanel.m
//
// Purpose:		Abstract superclass which facilitates creating dialogs that 
//				extend NSPanel. This handles the weirdo memory management 
//				associated with doing that. We also provided memory management 
//				for an NSObjectController for bindings.
//
//				Subclasses must override -panelNibName.
//
//  Created by Allen Smith on 9/10/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "DialogPanel.h"


@interface DialogPanel ()
{
	// The nib's other top-level objects (object controller, formatters), owned by the panel the nib made.
	// The new nib loader doesn't retain them, and objectController is an __unsafe_unretained outlet.
	NSArray *nibTopLevelObjects;
}
@end


@implementation DialogPanel

#pragma mark -
#pragma mark INITIALIZATION
#pragma mark -

//========== init ==============================================================
//
// Purpose:		Loads the panel from the Nib file specified by the subclass and 
//				returns it.
//
// Notes:		Subclasses MUST call this method by writing
//					self = [super init];
//				Because the object returned by this method will ALWAYS be 
//				different from the receiver.
//				
//				Yes, memory management is tricky here. The receiver is a 
//				throwaway object that exists soley to load a Nib file. We then 
//				junk the receiver and return a reference to the panel it loaded 
//				in the Nib. Tricky, huh?
//
//==============================================================================
- (id) init
{
	NSArray			*topLevelObjects	= nil;
	NSMutableArray	*panelOwns			= nil;
	
	[[NSBundle bundleForClass:[self class]] loadNibNamed:[self panelNibName] owner:self topLevelObjects:&topLevelObjects];
	
	// The receiver is thrown away, so the panel it loaded owns the other top-level objects (under MRC the 
	// panel released objectController in -dealloc). The panel itself is left out: the caller owns it, and 
	// listing it here would make a cycle.
	if(dialogPanel != nil)
	{
		panelOwns = [NSMutableArray arrayWithArray:topLevelObjects];
		[panelOwns removeObjectIdenticalTo:dialogPanel];
		dialogPanel->nibTopLevelObjects = panelOwns;
	}
	
	//this don't look good, but it works.
	//this takes the place of calling [super init]
	// Note that connections in the Nib file must be made 
	// to the PieceCountPanel, not to the File's Owner!
	
	return dialogPanel;
	
}//end init


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== panelNibName ======================================================
//
// Purpose:		Subclasses must override this method to return the name of the 
//				Nib which contains the desired panel.
//
// Notes:		The Nib should have this object as the File's Owner, but should 
//				also contain another instance of this class to which all other 
//				connections are made.
//
//==============================================================================
- (NSString *) panelNibName
{
	NSLog(@"No Nib name has been specified for this panel!");
	
	return nil;
	
}//end panelNibName


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//========== okButtonClicked: ==================================================
//
// Purpose:		End the sheet (we are the sheet--or at least we'd better be!)
//
//==============================================================================
- (IBAction) okButtonClicked:(id)sender
{
	[NSApp endSheet:self];
	[self close];
	
	//The object controller apparently retains its content. We must break that 
	// cycle in order to fully deallocate.
	[objectController setContent:nil];
	
}//end okButtonClicked:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		Our goose is cooked.
//
//==============================================================================
//end dealloc


@end

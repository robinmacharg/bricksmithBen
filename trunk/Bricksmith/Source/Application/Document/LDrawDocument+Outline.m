//==============================================================================
//
// File:		LDrawDocument+Outline.m
//
// Purpose:		The file contents outline view: data source, drag and drop, and
//				delegate (selection).
//
//				A category of LDrawDocument, split out of LDrawDocument.m (P4) so
//				that P10 can port it on its own. Shared declarations and the
//				instance variables are in LDrawDocument+Private.h.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument+Private.h"
#import "Bricksmith-Swift.h"

@implementation LDrawDocument (Outline)

#pragma mark -
#pragma mark OUTLINE VIEW
#pragma mark -

#pragma mark Data Source

//**** NSOutlineViewDataSource ****
//========== outlineView:numberOfChildrenOfItem: ===============================
//
// Purpose:		Returns the number of items which should be displayed under an 
//				expanded item.
//
//==============================================================================
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	NSInteger numberOfChildren = 0;
	
	//root object; return the number of submodels
	if(item == nil)
		numberOfChildren = [[documentContents submodels] count];
	
	//a step or model (or something); return the nth directives command
	else if([item isKindOfClass:[LDrawContainer class]])
		numberOfChildren = [[item subdirectives] count];

	return numberOfChildren;
	
}//end outlineView:numberOfChildrenOfItem:


//**** NSOutlineViewDataSource ****
//========== outlineView:isItemExpandable: =====================================
//
// Purpose:		Returns the number of items which should be displayed under an 
//				expanded item.
//
//==============================================================================
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	//You can expand models and steps.
	if([item isKindOfClass:[LDrawContainer class]] )
		return YES;
	else
		return NO;
	
}//end outlineView:isItemExpandable:


//**** NSOutlineViewDataSource ****
//========== outlineView:child:ofItem: =========================================
//
// Purpose:		Returns the child of item at the position index.
//
//==============================================================================
- (id)outlineView:(NSOutlineView *)outlineView
			child:(NSInteger)index
		   ofItem:(id)item
{
	NSArray *children = nil;
	
	//children of the root object; the nth of models.
	if(item == nil)
		children = [documentContents submodels];
		
	//a container; return the nth subdirective.	
	else if([item isKindOfClass:[LDrawContainer class]])
		children = [item subdirectives];

	return [children objectAtIndex:index];
	
}//end outlineView:child:ofItem:


//**** NSOutlineViewDataSource ****
//========== outlineView:objectValueForTableColumn:byItem: =====================
//
// Purpose:		Returns the representation of item given for the given table 
//				column.
//
//==============================================================================
- (id)			outlineView:(NSOutlineView *)outlineView
  objectValueForTableColumn:(NSTableColumn *)tableColumn
					 byItem:(id)item
{
	//Start off with a simple error message. Hopefully we won't see it.
	id representation = @"<Something went wrong here.>";
	
	//an LDraw directive; thank goodness! It knows how to describe itself.
	// The description will form the basis of the attributed text for the cell.
	if([item isKindOfClass:[LDrawDirective class]]) {
		representation = [item browsingDescription];
		
		//Apply formatting to our little string.
		representation = [self formatDirective:item
					  withStringRepresentation:representation];
    }

	return representation;

}//end outlineView:objectValueForTableColumn:byItem:


#pragma mark -
#pragma mark Drag and Drop

//**** NSOutlineViewDataSource ****
//========== outlineView:writeItems:toPasteboard: ==============================
//
// Purpose:		Initiates a drag. We drag directives by copying them at the 
//				outset. Upon the successful completion of the drag, we "paste" 
//				the copied directives wherever they landed, then delete the 
//				original objects.
//
//				We also drag a string representation of the objects for the 
//				benefit of other applications.
//
//==============================================================================
- (BOOL)outlineView:(NSOutlineView *)outlineView
		 writeItems:(NSArray *)items
	   toPasteboard:(NSPasteboard *)pboard
{
	NSInteger		numberItems = [items count];
	NSMutableArray	*rowIndexes = [NSMutableArray arrayWithCapacity:numberItems];
	NSInteger		itemIndex	= 0;
	NSInteger		counter 	= 0;
	LDrawDirective	*firstItem	= [items objectAtIndex:0];
	BOOL disallow = NO;
	
	// Disallow dragging if it is the only step in the model
	if(		[items count] == 1
	   &&	[firstItem isKindOfClass:[LDrawStep class]]
	   &&	[[[firstItem enclosingModel] steps] count] == 1)
	{
		disallow = YES;
	}
	
	//Write the objects as data.
	[self writeDirectives:items toPasteboard:pboard];
	
	//Now write the row indexes out. We'll use them to delete the original 
	// objects in the event of a successful drag.
	for(counter = 0; counter < numberItems; counter++){
		itemIndex = [outlineView rowForItem:[items objectAtIndex:counter]];
		[rowIndexes addObject:[NSNumber numberWithInteger:itemIndex]];
	}
	[pboard addTypes:[NSArray arrayWithObjects:LDrawDragSourceRowsPboardType, LDrawDisallowDragToSourcePboardType, nil]
			   owner:nil];
	[pboard setPropertyList:rowIndexes forType:LDrawDragSourceRowsPboardType];
	
	if(disallow)
		[pboard setPropertyList:(id)kCFBooleanTrue forType:LDrawDisallowDragToSourcePboardType];
	else
		[pboard setPropertyList:(id)kCFBooleanFalse forType:LDrawDisallowDragToSourcePboardType];
	
	return YES;
	
}//end outlineView:writeItems:toPasteboard:


//**** NSOutlineViewDataSource ****
//========== outlineView:validateDrop:proposedItem:proposedChildIndex: =========
//
// Purpose:		Returns the representation of item given for the given table 
//				column.
//
//==============================================================================
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView
				   validateDrop:(id <NSDraggingInfo>)info
				   proposedItem:(id)newParent
			 proposedChildIndex:(NSInteger)index
{
	NSPasteboard		*pasteboard		= [info draggingPasteboard];
	NSOutlineView		*sourceView		= [info draggingSource];
	NSDragOperation		 dragOperation	= NSDragOperationNone;
	
	//Fix our logic for handling drags to the root of the outline.
	if(newParent == nil)
		newParent = [self documentContents];
	
	//We must make sure we have the proper pasteboard type available.
	if(		index != NSOutlineViewDropOnItemIndex //not a "drop-on" operation.
	   &&	[[pasteboard types] containsObject:LDrawDirectivePboardType])
	{
		
		//This drag is acceptable. Now figure out the operation.
		if(sourceView == outlineView)
			dragOperation = NSDragOperationMove;
		else
			dragOperation = NSDragOperationCopy;
		
		//---------- Eliminate Illegal Positions -------------------------------
		
		//Read the first object off the pasteboard so we can figure 
		// out where this drop is allowed to happen.
		NSArray			*objects		= [pasteboard propertyListForType:LDrawDirectivePboardType];
		NSData			*data			= nil;
		id				 currentObject	= nil;
		
		//Unarchive.
		data			= [objects objectAtIndex:0];
		currentObject	= [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		//Now pop the data into our file.
		if(		sourceView == outlineView
		   &&	[[pasteboard types] containsObject:LDrawDisallowDragToSourcePboardType]
		   &&	[[pasteboard propertyListForType:LDrawDisallowDragToSourcePboardType] boolValue])
		{
//			NSLog(@"killing prohibited-into-source drag");
			dragOperation	= NSDragOperationNone;
		}
		
		else if(	[currentObject	isKindOfClass:[LDrawModel class]] == YES
				&&	[newParent		isKindOfClass:[LDrawFile class]] == NO)
		{
//			NSLog(@"killing model-not-in-file drag");
			dragOperation	= NSDragOperationNone;
		}
			
		else if(	[currentObject	isKindOfClass:[LDrawStep class]] == YES
				&&	[newParent		isKindOfClass:[LDrawModel class]] == NO)
		{
//			if([newParent isKindOfClass:[LDrawStep class]])
//				[outlineView setDropItem:[newParent enclosingDirective]
//							dropChildIndex:0];
//			NSLog(@"rejecting step drag to %@", [newParent class]);
			dragOperation	= NSDragOperationNone;
		}
		
		else if(	[currentObject	isKindOfClass:[LDrawContainer class]] == NO
				&&	[newParent		isKindOfClass:[LDrawContainer class]] == NO)
		{
//			NSLog(@"killing thingy-not-in-step");
			dragOperation	= NSDragOperationNone;
		}

        // Prohibit dragging non-constraint objects onto an LDrawLSynth part
        else if (   [currentObject	isKindOfClass:[LDrawPart class]]
                 && [newParent isKindOfClass:[LDrawLSynth class]]
                 && ![[LSynthConfiguration sharedInstance] isLSynthConstraint:currentObject]) {
            dragOperation	= NSDragOperationNone;
        }

        // Prohibit dragging things onto a container that it's not happy to accept
        else if (   [newParent isKindOfClass:[LDrawContainer class]]
                 && ![(LDrawContainer *)newParent acceptsDroppedDirective:currentObject]) {
            dragOperation	= NSDragOperationNone;
        }
	}
	return dragOperation;

}//end outlineView:validateDrop:proposedItem:proposedChildIndex:


//**** NSOutlineViewDataSource ****
//========== outlineView:acceptDrop:item:childIndex: ===========================
//
// Purpose:		Finishes the current drop, depositing as near as possible to 
//				the specified item.
//
// Notes:		Complexities lie within. Note them carefully.
//
//==============================================================================
- (BOOL)outlineView:(NSOutlineView *)outlineView
		 acceptDrop:(id <NSDraggingInfo>)info
			   item:(id)newParent
		 childIndex:(NSInteger)dropIndex
{
	//Identify the root object if needed.
	if(newParent == nil)
		newParent = [self documentContents];
	
	NSPasteboard    *pasteboard             = [info draggingPasteboard];
	NSUndoManager   *undoManager            = [self undoManager];
	NSOutlineView   *sourceView             = [info draggingSource];
	NSMutableArray  *doomedObjects          = [NSMutableArray array];
	NSArray         *pastedObjects          = nil;
	BOOL            renameDuplicateModels   = YES;
	NSInteger       counter                 = 0;
	
	if(sourceView == outlineView)
	{
		//We dragged within the same table. That means we expect the original 
		// objects dragged to "move" to the new position. Well, we can't 
		// actually *move* them, since our drag is implemented as a copy-and-paste.
		// However, we can simply delete the original objects, which will 
		// look the same anyway.
		//
		// Note we're doing this *before* moving, so that the indexes are 
		// still correct.
		NSArray         *rowsToDelete   = nil;
		NSInteger       doomedIndex     = 0;
		LDrawDirective  *objectToDelete = nil;
		
		//Gather up the objects we'll be removing.
		rowsToDelete = [pasteboard propertyListForType:LDrawDragSourceRowsPboardType];
		for(counter = 0; counter < [rowsToDelete count]; counter++)
		{
			doomedIndex = [[rowsToDelete objectAtIndex:counter] integerValue];
			objectToDelete = [outlineView itemAtRow:doomedIndex];
			[doomedObjects addObject:objectToDelete];
		}
		
		// When rearranging models within a file, don't do "copy X" renaming.
		renameDuplicateModels = NO;
	}

    // Gather up (unique) parents that are donating child nodes to this move
    // If the parents support tidying up they'll be given a chance later.
    // This is intended for e.g. containers such as LDrawSynth that may need
    // to take action if their subdirectives change.
    NSMutableSet *donatingParents = [[NSMutableSet alloc] init];
    for (LDrawPart *part in doomedObjects) {
		NSObject * donatingParent = [sourceView parentForItem:part];
		if(donatingParent != nil)
			[donatingParents addObject:donatingParent];
    }

    // Do The Move.
	pastedObjects = [self pasteFromPasteboard:pasteboard
						preventNameCollisions:renameDuplicateModels
									   parent:newParent
										index:dropIndex];
	
	if(sourceView == outlineView)
	{
		//Now that we've inserted the new objects, we need to delete the 
		// old ones.
		for(counter = 0; counter < [doomedObjects count]; counter++)
			[self deleteDirective:[doomedObjects objectAtIndex:counter]];
		
		[undoManager setActionName:NSLocalizedString(@"UndoReorder", nil)];
	}

    // Ask the source and target parents to cleanup if they can e.g. used for
    // updating container selection state
    for (LDrawDirective *parent in [donatingParents allObjects]) {
        if ([parent isKindOfClass:[LDrawContainer class]] &&
            [parent respondsToSelector:@selector(cleanupAfterDropIsDonor:)]) {
            [parent performSelector:@selector(cleanupAfterDropIsDonor:) withObject:[NSNumber numberWithBool:YES]];
        }
    }

    if ([newParent respondsToSelector:@selector(cleanupAfterDropIsDonor:)]) {
        [newParent performSelector:@selector(cleanupAfterDropIsDonor:) withObject:[NSNumber numberWithBool:NO]];
    }

    //And lastly, select the dragged objects.
	[(LDrawFileOutlineView*)outlineView selectObjects:pastedObjects];

	return YES;
	
}//end outlineView:acceptDrop:item:childIndex:



#pragma mark -
#pragma mark Delegate

//**** NSOutlineView ****
//========== outlineView:willDisplayCell:forTableColumn:item: ==================
//
// Purpose:		Returns the representation of item given for the given table 
//				column.
//
//==============================================================================
- (void) outlineView:(NSOutlineView *)outlineView
	 willDisplayCell:(id)cell
	  forTableColumn:(NSTableColumn *)tableColumn
				item:(id)item
{
	NSString	*imageName = nil;
	NSImage		*theImage;
	
	if([item isKindOfClass:[LDrawDirective class]])
		imageName = [item iconName];
		
	if(imageName == nil || [imageName isEqualToString:@""])
		theImage = nil;
	else
		theImage = [NSImage imageNamed:imageName];
		
	[(IconTextCell *)cell setImage:theImage];
	
}//end outlineView:willDisplayCell:forTableColumn:item:


//**** NSOutlineView ****
//========== outlineViewSelectionDidChange: ====================================
//
// Purpose:		We have selected a different something in the file contents.
//				We need to show it as selected in the OpenGL viewing area.
//				This means we may have to change the active model or step in 
//				order to display the selection.
//
//==============================================================================
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSOutlineView   *outlineView        = [notification object];
	NSArray         *selectedObjects    = [self selectedObjects];
	id              lastSelectedItem    = [outlineView itemAtRow:[outlineView selectedRow]];
	LDrawMPDModel   *selectedModel      = [self selectedModel];
	LDrawStep       *selectedStep       = [self selectedStep];
	NSInteger		selectedStepIndex	= 0;
	NSInteger       counter             = 0;
	
	// This method can be called from LDrawOpenGLView (in which case we already 
	// have a context we want to use) or it might be called on its own. Since 
	// selecting parts can trigger OpenGL commands, we should make sure we have 
	// a context active, but we should also restore the current context when 
	// we're done. 
	NSOpenGLContext *originalContext = [NSOpenGLContext currentContext];
	[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
	
	//Deselect all the previously-selected directives
	// (clears the internal directive flag used for drawing)
	for(counter = 0; counter < [self->selectedDirectives count]; counter++)
		[[selectedDirectives objectAtIndex:counter] setSelected:NO];
	
	//Tell the newly-selected directives that they just got selected.
	selectedDirectives = selectedObjects;
	for(counter = 0; counter < [self->selectedDirectives count]; counter++)
		[[selectedDirectives objectAtIndex:counter] setSelected:YES];
	
	// Update things which need to take into account the entire selection.
    // The order matters: the search panel unregisters itself as the active colorwell
    // before the inspector or color panel do their thing.
	if([SearchPanelController isVisible])
	{
		[[SearchPanelController searchPanel] updateInterfaceForSelection:selectedObjects];
	}
	[[LDrawApplication sharedInspector] inspectObjects:selectedObjects];
	[[LDrawColorPanelController sharedColorPanel] updateSelectionWithObjects:selectedObjects];
    
	if(selectedModel != nil)
	{
		// Put the selection on screen (if we need to)
		[self setActiveModel:selectedModel];
		
		// Advance to the current step (if we need to)
		if(selectedStep != nil)
		{
			selectedStepIndex = [selectedModel indexOfDirective:selectedStep];
			
			if(selectedStepIndex > [selectedModel maxStepIndexToOutput])
			{
				[self setCurrentStep:selectedStepIndex]; // update document UI
			}
		}
	}
	[[self documentContents] noteNeedsDisplay];
	
	//See if we just selected a new part; if so, we must remember it.
	if ([lastSelectedItem isKindOfClass:[LDrawPart class]] ||
        [lastSelectedItem isKindOfClass:[LDrawLSynth class]])
		[self setLastSelectedPart:lastSelectedItem];

	[self buildRelatedPartsMenus];
	[originalContext makeCurrentContext];
	
}//end outlineViewSelectionDidChange:

@end

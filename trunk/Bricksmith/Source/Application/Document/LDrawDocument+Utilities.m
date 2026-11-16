//==============================================================================
//
// File:		LDrawDocument+Utilities.m
//
// Purpose:		Utilities: adding models, steps and parts, selection queries,
//				formatting, pasteboard reading and writing.
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

@implementation LDrawDocument (Utilities)

#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== addModel: =========================================================
//
// Purpose:		Add newModel to the current file.
//
// Notes:		Duplicate model names are verboten if renameModels is true, so 
//				if newModel's name matches an existing model name, an approriate 
//				"copy X" will be appended automatically. 
//
//				There is a bug here in that if several models having references 
//				to one another are pasted at once into a file with name 
//				conflicts, the file reference structure of the pasted models 
//				will point to the wrong names once this method does its renaming 
//				magic. To this I respond, "don't do that."
//
//==============================================================================
- (void) addModel:(LDrawMPDModel *)newModel atIndex:(NSInteger)insertAtIndex preventNameCollisions:(BOOL)renameModels
{
	NSString        *proposedModelName  = [newModel modelName];
	NSUndoManager   *undoManager        = [self undoManager];
	NSInteger       rowForItem          = 0;
	
	// Derive a non-duplicating name for this new model
	if(renameModels == YES)
	{
		while([[self documentContents] modelWithName:proposedModelName] != nil)
		{
			proposedModelName = [StringUtilities nextCopyPathForFilePath:proposedModelName];
		}
		[newModel setModelName:proposedModelName];
	}
	
	// Insert
	if(insertAtIndex == NSNotFound)
	{
		[self addDirective:newModel toParent:[self documentContents]];
	}
	else
	{
		[self addDirective:newModel toParent:[self documentContents] atIndex:insertAtIndex];
	}
	
	// Select the new model.
	// Ben says: why is it legal for us to directly synchronously select the mode? (This is one of the 
	// only cases where we do?)  Adding a directive to the parent file (which is what adding a model
	// does) causes us to get a notification _directly_ off of the doc's file. Notifications off of 
	// the doc's file are handled synchronously, so by the time we get here, we are totally UI-synced.
	//
	// This is good because we are also going to hierarchy-expand our new model to reveal its first
	// step, so we this code is going to have to talk to the outliner no matter what.
	[fileContentsOutline expandItem:newModel];
	rowForItem = [fileContentsOutline rowForItem:newModel];
	[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:rowForItem]
					 byExtendingSelection:NO];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddModel", nil)];
	
}//end addModel:


//========== addStep:parent:index: =============================================
//
// Purpose:		Adds newStep to the currently-displayed model. If you specify an 
//				index, it will be inserted there. Otherwise, the step appears at 
//				the end of the list. 
//
//==============================================================================
- (void) addStep:(LDrawStep *)newStep parent:(LDrawMPDModel*)selectedModel index:(NSInteger)insertAtIndex
{
	NSUndoManager	*undoManager	= [self undoManager];
	
	// Synchronize our addition with the model currently active.
	if(selectedModel == nil)
		selectedModel = [[self documentContents] activeModel];
	else
		[[self documentContents] setActiveModel:selectedModel];
	
	// Insert
	if(insertAtIndex == NSNotFound)
	{
		[self addDirective:newStep toParent:selectedModel];
	}
	else
	{
		[self addDirective:newStep toParent:selectedModel atIndex:insertAtIndex];
	}
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddStep", nil)];	
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newStep]];
	
}//end addStep:


//========== addPartNamed: =====================================================
//
// Purpose:		Adds a part with the given name to the current step in the 
//				currently-displayed model.
//
//==============================================================================
- (void) addPartNamed:(NSString *)partName
{
	LDrawPart           *newPart        = [[LDrawPart alloc] init];
	NSUndoManager       *undoManager    = [self undoManager];
	LDrawColor          *selectedColor  = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	TransformComponents transformation  = IdentityComponents;
	
	//We got a part; let's add it!
	if(partName != nil)
	{
		//Set up the part attributes
		[newPart setLDrawColor:selectedColor];
		[newPart setDisplayName:partName];
		
		if(self->lastSelectedPart != nil)
		{
			// Collect the transformation from the previous part and apply it to 
			// the new one. 
			transformation = [lastSelectedPart transformComponents];
			[newPart setTransformComponents:transformation];
		}
		
		[self addStepComponent:newPart parent:nil index:NSNotFound];
		
		[undoManager setActionName:NSLocalizedString(@"UndoAddPart", nil)];
		[self flushDocChangesAndSelect:[NSArray arrayWithObject:newPart]];
	}
}//end addPartNamed:


//========== addStepComponent: =================================================
//
// Purpose:		Adds newDirective to the bottom of the current step, or after 
//				the currently-selected element in the step if there is one.
//
// Parameters:	newDirective: a directive which can be added to a step. These 
//						include parts, geometric primitives, and comments.
//				parent - requested target step; if nil, uses the default behavior
//				insertAtIndex - index in parent.
//
// Note:			This routine _no longer_ selects the added step component!  All
//				code that calls addStepComponent must manage selection on its
//				own.  Selection has been pulled out of addStepComponent because
//				many operations involve a large number of step components;
//				editing the selection per directive turns into a huge
//				performance problem.
//
//==============================================================================
- (void) addStepComponent:(LDrawDirective *)newDirective
				   parent:(LDrawContainer*)parent
					index:(NSInteger)insertAtIndex
{
	LDrawContainer	*targetContainer	= parent;
	LDrawMPDModel	*selectedModel		= [self selectedModel];

	// Synchronize our addition with the model currently active.
	if(selectedModel == nil)
		selectedModel = [[self documentContents] activeModel];
	else
		[[self documentContents] setActiveModel:selectedModel];
	
	// We may have the model itself selected, in which case we will add this new 
	// element to the very bottom of the model.
	if(targetContainer == nil)
	{
		LDrawContainer *selectedContainer = [self selectedContainer];
		
		if(		selectedContainer != nil
		   &&	[selectedContainer isKindOfClass:[LDrawFile class]] == NO
		   &&	[selectedContainer isKindOfClass:[LDrawModel class]] == NO
		   &&	[selectedContainer isKindOfClass:[LDrawStep class]] == NO
           &&   [selectedContainer acceptsDroppedDirective:newDirective] == YES)
		{
			// If we have an "interesting" container selected -- like a texture 
			// -- that accepts the dropped directive add directives to it instead
			// of at the end of the model. The theory here is that these special
			// containers are kind of their  own little world, and as long as you
			// have one selected, you should continue working within it.
			targetContainer = selectedContainer;
		}        
        // We can't find a container that wants this part so add it to the bottom of the model
		else
		{
			targetContainer = [selectedModel visibleStep];
		}
	}
	if(insertAtIndex == NSNotFound)
	{
		// At a user's request, all new components are inserted in the last 
		// visible step. That's how duplicating drag-and-drops work anyway. 
		[self addDirective:newDirective toParent:targetContainer ];
	}
	else
	{
		[self addDirective:newDirective toParent:targetContainer atIndex:insertAtIndex ];
	}

	// This code used to do a synchronous doc update and select the part right here.
	// This has been removed and hoisted out to the calling code - pretty much anyone
	// calling this should call flushDocChangesAndSelect.

	// Allow us to immediately use the keyboard to move the new part.
	[[self foremostWindow] makeFirstResponder:mostRecentLDrawView];
	
}//end addStepComponent:


#pragma mark -

//========== canDeleteDirective:displayErrors: =================================
//
// Purpose:		Tests whether the specified directive should be allowed to be 
//				deleted. If errorFlag is YES, also displays an appropriate error 
//				sheet explaining the reasons why directive cannot be deleted.
//
//==============================================================================
- (BOOL) canDeleteDirective:(LDrawDirective *)directive
			  displayErrors:(BOOL)errorFlag
{
	LDrawContainer	*parentDirective	= [directive enclosingDirective];
	BOOL			 isLastDirective	= ([[parentDirective subdirectives] count] <= 1);
	NSAlert			*alert				= nil;
	NSString		*message			= nil;
	NSString		*informative		= nil;
	BOOL			 canDelete			= YES;
	
	if([directive isKindOfClass:[LDrawModel class]] && isLastDirective == YES)
	{
		canDelete = NO;
		informative = NSLocalizedString(@"DeleteLastModelInformative", nil);
	}
	else if([directive isKindOfClass:[LDrawStep class]] && isLastDirective == YES)
	{
		canDelete = NO;
		informative = NSLocalizedString(@"DeleteLastStepInformative", nil);
	}
	
	if(canDelete == NO && errorFlag == YES)
	{
		message = NSLocalizedString(@"DeleteDirectiveError", nil);
		message = [NSString stringWithFormat:message, [directive browsingDescription]];
		
		alert = [[NSAlert alloc] init];		
		[alert setMessageText:message];
		[alert setInformativeText:informative];
		
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		
		[alert beginSheetModalForWindow:[self windowForSheet]
					  completionHandler:nil];

		
	}
	
	
	return canDelete;
	
}//end canDeleteDirective:displayErrors:


//========== elementsAreSelectedOfVisibility: ==================================
//
// Purpose:		Returns YES if there are elements selected which have the 
//				requested visibility. 
//
//==============================================================================
- (BOOL) elementsAreSelectedOfVisibility:(BOOL)visibleFlag
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	BOOL        invisibleSelected   = NO;
	BOOL        visibleSelected     = NO;
	
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject respondsToSelector:@selector(isHidden)])
		{
			invisibleSelected	= invisibleSelected || [currentObject isHidden];
			visibleSelected		= visibleSelected   || ([currentObject isHidden] == NO);
		}
	}
	
	if(visibleFlag == YES)
		return visibleSelected;
	else
		return invisibleSelected;
		
}//end elementsAreSelectedOfVisibility:


//========== formatDirective:withStringRepresentation: =========================
//
// Purpose:		Applies syntax coloring to the specified directive, which will 
//				be displayed with the text representation.
//
//==============================================================================
- (NSAttributedString *) formatDirective:(LDrawDirective *)item
				withStringRepresentation:(NSString *)representation
{
	NSUserDefaults			*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSString				*colorKey		= nil; //preference key for object's syntax color.
	NSColor					*syntaxColor	= nil;
	NSNumber				*obliqueness	= [NSNumber numberWithDouble:0.0]; //italicize?
	NSAttributedString		*styledString	= nil;
	NSMutableDictionary		*attributes		= [NSMutableDictionary dictionary];
	NSMutableParagraphStyle	*paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	//We want the text to appear nicely truncated in its column.
	// By setting the column to wrap and then setting the paragraph wrapping to 
	// truncate, we achieve the desired effect.
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	
	//Find the specified syntax color for the directive.
	if([item isKindOfClass:[LDrawModel class]])
		colorKey = SYNTAX_COLOR_MODELS_KEY;
	
	else if([item isKindOfClass:[LDrawStep class]])
		colorKey = SYNTAX_COLOR_STEPS_KEY;
	
	else if([item isKindOfClass:[LDrawComment class]])
		colorKey = SYNTAX_COLOR_COMMENTS_KEY;
		
	else if([item isKindOfClass:[LDrawPart class]])
		colorKey = SYNTAX_COLOR_PARTS_KEY;

    else if ([item isKindOfClass:[LDrawLSynth class]] ||
             [item isKindOfClass:[LDrawLSynthDirective class]])
        colorKey = SYNTAX_COLOR_PARTS_KEY;

	else if([item isKindOfClass:[LDrawLine				class]] ||
	        [item isKindOfClass:[LDrawTriangle			class]] ||
			[item isKindOfClass:[LDrawQuadrilateral		class]] ||
			[item isKindOfClass:[LDrawConditionalLine	class]]    )
		colorKey = SYNTAX_COLOR_PRIMITIVES_KEY;
	
	else if([item isKindOfClass:[LDrawColor class]])
		colorKey = SYNTAX_COLOR_COLORS_KEY;
	
	else
		colorKey = SYNTAX_COLOR_UNKNOWN_KEY;
	
	//We have the syntax coloring we want.
	syntaxColor = [userDefaults colorForKey:colorKey];
	
	if([item respondsToSelector:@selector(isHidden)])
		if([(id)item isHidden])
			obliqueness = [NSNumber numberWithDouble:0.5];
	
	
	//Assemble the attributes dictionary.
	[attributes setObject:paragraphStyle	forKey:NSParagraphStyleAttributeName];
	[attributes setObject:syntaxColor		forKey:NSForegroundColorAttributeName];
	[attributes setObject:obliqueness		forKey:NSObliquenessAttributeName];
	
	//Create the attributed string.
    styledString = [[NSAttributedString alloc]
							initWithString:representation
								attributes:attributes ];
	
	//Release stuff we created or copied.
	
	return styledString;

}//end formatDirective:withStringRepresentation:


//========== loadDataIntoDocumentUI ============================================
//
// Purpose:		Informs the document's user interface widgets about the contents 
//				of the document they are supposed to be representing.
//
//				There are two occasions when this method must be called:
//					1) immediately after the document UI has first been loaded
//						(in windowControllerDidLoadNib:)
//					2) when reverting the document.
//						(in revertToSavedFromFile:ofType:)
//
//==============================================================================
- (void) loadDataIntoDocumentUI
{
	NSArray<LDrawGLView*>*	graphicViews	= [self all3DViewports];
	NSUInteger				counter 		= 0;

	for(counter = 0; counter < [graphicViews count]; counter++)
	{
		[[graphicViews objectAtIndex:counter] setLDrawDirective:[self documentContents]];
	}
	[self->fileContentsOutline	reloadData];
	
	[self addModelsToMenus];
	
	[self buildRelatedPartsMenus];

}//end loadDataIntoDocumentUI


//========== selectedContainer =================================================
//
// Purpose:		Returns the step that encloses (or is) the current selection, or
//				nil if there is no step in the selection chain.
//
//==============================================================================
- (LDrawContainer *) selectedContainer
{
	NSInteger		selectedRow 		= [fileContentsOutline selectedRow];
	id				selectedItem		= [fileContentsOutline itemAtRow:selectedRow];
	LDrawContainer	*selectedContainer	= nil;
	
	// Hack alert!
	// If we are doing a copy-drag operation, remember the original selection 
	// and use it. (We can't use the current selection during copy drag because 
	// we clear it when the drag begins.)
	if([self->selectedDirectivesBeforeCopyDrag count] > 0)
		selectedItem = [selectedDirectivesBeforeCopyDrag objectAtIndex:0];
	
	// Find selected container
	if([selectedItem isKindOfClass:[LDrawContainer class]])
		selectedContainer = selectedItem;
	else
		selectedContainer = [selectedItem enclosingDirective];
	
	return selectedContainer;
	
}//end selectedContainer


//========== selectedObjects ===================================================
//
// Purpose:		Returns the LDraw objects currently selected in the file.
//
//==============================================================================
- (NSArray *) selectedObjects
{
	NSIndexSet      *selectedIndexes    = [fileContentsOutline selectedRowIndexes];
	NSUInteger      currentIndex        = [selectedIndexes firstIndex];
	NSMutableArray  *selectedObjects    = [NSMutableArray arrayWithCapacity:[selectedIndexes count]];
	id              currentObject       = nil;
	
	//Search through all the indexes and get the objects associated with them.
	while(currentIndex != NSNotFound){
	
		currentObject = [fileContentsOutline itemAtRow:currentIndex];
		[selectedObjects addObject:currentObject];
		
		currentIndex = [selectedIndexes indexGreaterThanIndex:currentIndex];
	}
	
	return selectedObjects;
	
}//end selectedObjects


//========== selectedModel =====================================================
//
// Purpose:		Returns the model that encloses the current selection, or nil 
//				if there is no selection.
//
// Note:		If you intend to use this method's output to figure out which 
//				model to display, then you need to convert a nil case into the 
//				active model.
//
//==============================================================================
- (LDrawMPDModel *) selectedModel
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	return (LDrawMPDModel*)[selectedItem enclosingModel];

}//end selectedModel


//========== selectedModel =====================================================
//
// Purpose:		Returns the step that encloses (or is) the current selection, or  
//				nil if there is no step in the selection chain.
//
//==============================================================================
- (LDrawStep *) selectedStep
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	return [selectedItem enclosingStep];

}//end selectedStep


//========== selectedStepComponent =============================================
//
// Purpose:		Returns the drawable LDraw element that is currently selected.
//				(e.g., Part, Quadrilateral, Triangle, etc.)
//
//				Returns nil if the selection is not one of these atomic LDraw
//				commands.
//
//==============================================================================
- (LDrawDirective *) selectedStepComponent
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	//If a model is selected, a step can't be!
	if(		selectedItem == nil
       ||	[selectedItem isKindOfClass:[LDrawFile class]]
	   ||	[selectedItem isKindOfClass:[LDrawModel class]]
	   ||	[selectedItem isKindOfClass:[LDrawStep class]] )
		return nil;
	
	else { //it's not a file, model, or step; whatever it is, it's what we are 
			// looking for.
		return selectedItem;
	}
}//end selectedStep


//========== selectedPart ======================================================
//
// Purpose:		Returns the first part that is currently selected, or nil if no 
//				part is selected.
//
//==============================================================================
- (LDrawPart *) selectedPart
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	
	while(counter < [selectedObjects count])
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject isKindOfClass:[LDrawPart class]])
			break;
		else
			counter++;
	}
	
	//Either we just found one, on we found nothing.
	return currentObject;
}//end 


//========== updateInspector ===================================================
//
// Purpose:		Updates the Inspector to display the currently-selected objects.
//				This should be called in response to any potentially state-
//				changing actions on a directive.
//
//==============================================================================
- (void) updateInspector
{
	NSArray *selectedObjects = [self selectedObjects];
	
	[[LDrawApplication sharedInspector] inspectObjects:selectedObjects];
	[[LDrawColorPanelController sharedColorPanel] updateSelectionWithObjects:selectedObjects];
	
}//end updateInspector


//========== updateViewingAngleToMatchStep =====================================
//
// Purpose:		Sets the viewing angle of the main viewport to the angle 
//				requested by the current step for Step Display mode. 
//
//==============================================================================
- (void) updateViewingAngleToMatchStep
{
	LDrawMPDModel       *activeModel        = [[self documentContents] activeModel];
	NSInteger           requestedStep       = [activeModel maximumStepIndexForStepDisplay];
	Tuple3              viewingAngle        = [activeModel rotationAngleForStepAtIndex:requestedStep];
	ViewOrientationT    viewOrientation     = [LDrawUtilities viewOrientationForAngle:viewingAngle];
	LDrawGLView         *affectedViewport   = [self main3DViewport];
	
	// Set the Viewing angle
	if(viewOrientation != ViewOrientation3D)
		[affectedViewport setProjectionMode:ProjectionModeOrthographic];
	else
		[affectedViewport setProjectionMode:ProjectionModePerspective];
	
	[affectedViewport setViewOrientation:viewOrientation];
	[affectedViewport setViewingAngle:viewingAngle];
	[affectedViewport setLocationMode:LocationModeModel];
	
}//end updateViewingAngleToMatchStep


//========== writeDirectives:toPasteboard: =====================================
//
// Purpose:		Writes objects to the given pasteboard, ensuring that each 
//				directive is written only once.
//
//				This method places two arrays on the pasteboard for these types:
//				* LDrawDirectivePboardType: array of LDrawDirectives converted 
//							to NSData objects.
//				* NSStringPboardType: array of strings representing the objects 
//							in the format written to an LDraw file.
//
// Notes:		This method will clear the contents of the pasteboard.
//
//==============================================================================
- (void) writeDirectives:(NSArray *)directives
			toPasteboard:(NSPasteboard *)pasteboard
{
	//Pasteboard types.
	NSArray			*pboardTypes		= [NSArray arrayWithObjects:
												LDrawDirectivePboardType, //Bricksmith's preferred type.
												NSStringPboardType, //representation for other applications.
												nil ];
	LDrawDirective	*currentObject		= nil;
	NSMutableArray	*objectsToCopy		= [NSMutableArray array];
	//list of containers we've already archived. We don't want to re-archive any 
	// of their children.
	NSMutableArray	*archivedContainers	= [NSMutableArray array];
	NSData			*data				= nil;
	NSString		*string				= nil;
	//list of LDrawDirectives which have been converted to data.
	NSMutableArray	*archivedObjects	= [NSMutableArray array];
	//list of LDrawDirectives which have been converted to strings.
	NSMutableString	*stringedObjects	= [NSMutableString stringWithCapacity:256];
	NSInteger		counter				= 0;
	
	//Write out the selected objects, but only once for each object. 
	// Don't write out items whose parent is selected; the parent will 
	// automatically write its children.
	for(counter = 0; counter < [directives count]; counter++)
	{
		currentObject = [directives objectAtIndex:counter];
		//If we haven't already run into this object (via its parent container)
		// then we want to write it out. Otherwise, it will be copied implicitly 
		// along with its parent rather than copied explicitly.
		if([currentObject isAncestorInList:archivedContainers] == NO){
			[objectsToCopy addObject:currentObject];
		}
		//If this object is a container, we must record that it has been 
		// archived. Either it was archived just now, or it was archived 
		// earlier when its parent was archived.
		if([currentObject isKindOfClass:[LDrawContainer class]]){
			[archivedContainers addObject:currentObject];
		}
	}
	
	
	//Now that we have figured out *what* to copy, convert it into the 
	// *representations* we will use to copy.
	for(counter = 0; counter < [objectsToCopy count]; counter++)
	{
		currentObject = [objectsToCopy objectAtIndex:counter];
		
		//Convert the object into the two representations we know how to write.
		data	= [NSKeyedArchiver archivedDataWithRootObject:currentObject];
		string	= [currentObject write];
		
		//Save the representations into the arrays we'll write to the pasteboard.
		[archivedObjects addObject:data];
		[stringedObjects appendFormat:@"%@\n", string];
								//not using CRLF here because any Mac program that 
								// knows enough to do DOS line-endings will automatically
								// add them to pasted content.
	}
	
	
	//Set up our pasteboard.
	[pasteboard declareTypes:pboardTypes owner:nil];
	
	//Internally, Bricksmith uses archived LDrawDirectives to copy/paste.
	[pasteboard setPropertyList:archivedObjects forType:LDrawDirectivePboardType];
	
	//For other applications, however, we provide the LDraw file contents for 
	// the objects. Note that these strings cannot be pasted back into the 
	// program.
	[pasteboard setString:stringedObjects forType:NSStringPboardType];
	
}//end writeDirectives:toPasteboard:


//========== pasteFromPasteboard: ==============================================
//
// Purpose:		Paste the directives on the given pasteboard into the document.
//				The pasteboard must contain LDrawDirectivePboardType.
//
//				By generalizing the method in this way, we allow pasting off 
//				private internal pasteboards too. This method is used by 
//				-duplicate: in order to leverage the existing copy/paste code 
//				without wantonly destroying the contents of the General 
//				Pasteboard.
//
// Returns:		The objects added, or nil if nothing was on the pasteboard.
//
// Parameters:	pasteboard		- where the archived directives live
//				renameModels	- add "copy X" suffixes to pasted models as needed. 
//				parent			- add objects to this component (pass nil for default behavior)
//				insertAtIndex	- child index within parent (pass NSNotFound for default behavior)
//
//==============================================================================
- (NSArray *) pasteFromPasteboard:(NSPasteboard *) pasteboard
			preventNameCollisions:(BOOL)renameModels
						   parent:(LDrawContainer*)parent
							index:(NSInteger)insertAtIndex
{
	NSArray         *objects        = nil;
	id              currentObject   = nil; //some kind of unarchived LDrawDirective
	NSData          *data           = nil;
	NSMutableArray  *addedObjects   = [NSMutableArray array];
	NSInteger       counter         = 0;
		
	//We must make sure we have the proper pasteboard type available.
 	if([[pasteboard types] containsObject:LDrawDirectivePboardType])
	{
		//Unarchived everything and dump it into our file.
		objects = [pasteboard propertyListForType:LDrawDirectivePboardType];
		for(counter = 0; counter < [objects count]; counter++)
		{
			NSInteger real_index = insertAtIndex;
			if(real_index != NSNotFound)	real_index += counter;
			data			= [objects objectAtIndex:counter];
			currentObject	= [NSKeyedUnarchiver unarchiveObjectWithData:data];

            // Reset the object icon if we can.  New parents get a chance later (in e.g. outlineView:acceptDrop:)
            // to change them if they want
            if ([[currentObject class] respondsToSelector:@selector(defaultIconName)]) {
                NSString *iconName = [[currentObject class] performSelector:@selector(defaultIconName)];
                if (iconName) {
                    [currentObject setIconName:iconName];
                }
            }

			//Now pop the data into our file.
			if([currentObject isKindOfClass:[LDrawModel class]])
                [self addModel:currentObject atIndex:real_index preventNameCollisions:renameModels];
			else if([currentObject isKindOfClass:[LDrawStep class]])
				[self addStep:currentObject parent:(LDrawMPDModel*)parent index:real_index];
			else
			{
				[self addStepComponent:currentObject parent:parent index:real_index];
			}
			
			[addedObjects addObject:currentObject];
		}
		
		[self flushDocChangesAndSelect:addedObjects];

	}
	
	return addedObjects;
	
}//end pasteFromPasteboard:


//========== flushDocChangesAndSelect: =========================================
//
// Purpose:		This routine does two tasks that are almost always done 
//				together in most UI code:
//
//				(1) it "flushes" pending asynchronous UI updates by
//					directly posting a directive change (on our doc's file)
//					synchronously with coalescing. When this finishes, the 
//					outliner, model menu, etc. are all "synced up".
//
//				(2) it then completely changes the selection to a new set
//					of directives.  That could be 0, 1 or many directives.
//
// Notes:		This routine should be done once at the end of an editing
//				function; the sync and selection change are quite affordable
//				performance wise if they are done once per user edit.
//
//				This function should _not_ be done in lower level utility 
//				functions, undoable methods, or inside an iteration loop.
//
//				Typical use will be to make a series of low level directive
//				changes (all which post async doc updates) and then flush and
//				select once when all editing work is finished.
//==============================================================================
- (void) flushDocChangesAndSelect:(NSArray*)directives
{
	LDrawFile *docContents = [self documentContents];

	// Post a notification that our doc changed; LDrawGLView needs this 
	// to refresh drawing, and we ned it to redo our menus.
	NSNotification * doc_notification = 
		[NSNotification notificationWithName:LDrawDirectiveDidChangeNotification 
									 object:docContents];

	// Notification is queued and coalesced; 
	[[NSNotificationQueue defaultQueue] 
			enqueueNotification:doc_notification 
				postingStyle:NSPostNow 
				coalesceMask:NSNotificationCoalescingOnName|NSNotificationCoalescingOnSender
					forModes:NULL];
					
	[self selectDirectives:directives];
}//end flushDocChangesAndSelect:

@end
